-- Seller dashboard and insights (Blueprint fig. 30 Dashboard, section 42):
-- today's work, sales, products, money and a performance score, plus daily
-- sales, top products and Try-On insights (which products are tried on and
-- how tried-on shoppers convert). Views / add-to-bag / wishlist analytics
-- need event tracking and come with Phase 4.

-- Brand team members (any role) and Clothsy ops / finance.
create or replace function private.can_see_seller(p_seller_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_seller_member(p_seller_id)
      or private.is_staff(array['ops', 'finance']::public.app_role[]);
$$;

-- Performance over the last 90 days. A simple, explainable score until the
-- policy is set (🔑): 100, less up to 50 for cancelling orders and up to 50
-- for dispatching late.
create or replace function private.seller_performance(p_seller_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  with parts as (
    select so.* from public.seller_orders so
    where so.seller_id = p_seller_id
      and so.created_at > now() - interval '90 days'
      and so.status <> 'pending_payment'
      and not (so.status = 'cancelled' and so.cancelled_by = 'customer')
  ),
  stats as (
    select
      count(*) as orders,
      count(*) filter (where status = 'cancelled' and cancelled_by = 'seller') as seller_cancelled,
      count(*) filter (where shipped_at is not null) as shipped,
      count(*) filter (where shipped_at is not null and shipped_at > dispatch_by) as late
    from parts
  )
  select jsonb_build_object(
    'orders', orders,
    'seller_cancellation_rate', case when orders = 0 then 0 else round(seller_cancelled::numeric / orders, 4) end,
    'late_dispatch_rate', case when shipped = 0 then 0 else round(late::numeric / shipped, 4) end,
    'score', case when orders = 0 then null else greatest(0, round(
      100
      - 50 * seller_cancelled::numeric / orders
      - 50 * (case when shipped = 0 then 0 else late::numeric / shipped end)))::integer end)
  from stats;
$$;

create or replace function public.seller_dashboard(p_seller_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  today_start timestamptz := date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata';
  result jsonb;
begin
  if not private.can_see_seller(p_seller_id) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select jsonb_build_object(
    'orders', (
      select jsonb_build_object(
        'today', count(*) filter (where created_at >= today_start),
        'new', count(*) filter (where status = 'placed'),
        'to_pack', count(*) filter (where status = 'confirmed'),
        'to_ship', count(*) filter (where status = 'packed'),
        'in_transit', count(*) filter (where status in ('shipped', 'out_for_delivery')),
        'late', count(*) filter (where status in ('placed', 'confirmed', 'packed') and dispatch_by < now()))
      from public.seller_orders
      where seller_id = p_seller_id and status <> 'pending_payment'),
    'sales_30d', (
      select jsonb_build_object(
        'orders', count(distinct so.id),
        'units', coalesce(sum(i.quantity), 0),
        'gmv', coalesce(sum(i.line_total), 0),
        'aov', case when count(distinct so.id) = 0 then 0
                    else (coalesce(sum(i.line_total), 0) / count(distinct so.id))::integer end)
      from public.seller_orders so
      join public.order_items i on i.seller_order_id = so.id
      where so.seller_id = p_seller_id
        and so.created_at > now() - interval '30 days'
        and so.status not in ('pending_payment', 'cancelled')),
    'products', (
      select jsonb_build_object(
        'live', count(*) filter (where status = 'live'),
        'in_review', count(*) filter (where status = 'pending_review'),
        'rejected', count(*) filter (where status = 'rejected'),
        'drafts', count(*) filter (where status = 'draft'),
        'unpublished', count(*) filter (where status = 'archived'))
      from public.products where seller_id = p_seller_id),
    'low_stock', (
      select count(*) from public.product_variants v
      join public.products p on p.id = v.product_id
      where v.seller_id = p_seller_id and v.is_low_stock and p.status in ('live', 'pending_review')),
    'money', jsonb_build_object(
      'pending', (select coalesce(sum(net), 0) from public.seller_settlements
                  where seller_id = p_seller_id and status = 'pending'),
      'eligible', (select coalesce(sum(net), 0) from public.seller_settlements
                   where seller_id = p_seller_id and status = 'eligible'),
      'last_payout', (select jsonb_build_object('amount', amount, 'status', status, 'created_at', created_at)
                      from public.payouts where seller_id = p_seller_id
                      order by created_at desc limit 1)),
    'performance', private.seller_performance(p_seller_id)
  ) into result;
  return result;
end $$;
grant execute on function public.seller_dashboard(uuid) to authenticated;

-- Orders, units and item value per day (IST) for the last [p_days] days,
-- including days without sales.
create or replace function public.seller_sales_daily(p_seller_id uuid, p_days integer default 30)
returns table (day date, orders integer, units integer, gmv integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.can_see_seller(p_seller_id) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  return query
  with days as (
    select generate_series(
      (now() at time zone 'Asia/Kolkata')::date - (least(greatest(p_days, 1), 366) - 1),
      (now() at time zone 'Asia/Kolkata')::date,
      interval '1 day')::date as d
  ),
  sales as (
    select (so.created_at at time zone 'Asia/Kolkata')::date as d,
           count(distinct so.id)::integer as n_orders,
           sum(i.quantity)::integer as n_units,
           sum(i.line_total)::integer as value
    from public.seller_orders so
    join public.order_items i on i.seller_order_id = so.id
    where so.seller_id = p_seller_id
      and so.status not in ('pending_payment', 'cancelled')
      and so.created_at >= now() - make_interval(days => least(greatest(p_days, 1), 366) + 1)
    group by 1
  )
  select days.d, coalesce(sales.n_orders, 0), coalesce(sales.n_units, 0), coalesce(sales.value, 0)
  from days left join sales on sales.d = days.d
  order by days.d;
end $$;
grant execute on function public.seller_sales_daily(uuid, integer) to authenticated;

create or replace function public.seller_top_products(
  p_seller_id uuid,
  p_days integer default 30,
  p_limit integer default 10
)
returns table (product_id uuid, title text, units integer, gmv integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.can_see_seller(p_seller_id) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  return query
  select i.product_id, max(i.title), sum(i.quantity)::integer, sum(i.line_total)::integer
  from public.order_items i
  join public.seller_orders so on so.id = i.seller_order_id
  where so.seller_id = p_seller_id
    and so.status not in ('pending_payment', 'cancelled')
    and so.created_at > now() - make_interval(days => least(greatest(p_days, 1), 366))
  group by i.product_id
  order by 4 desc, 3 desc
  limit least(greatest(p_limit, 1), 50);
end $$;
grant execute on function public.seller_top_products(uuid, integer, integer) to authenticated;

-- Per product: previews made, shoppers who tried it on, and how many of them
-- went on to order it. Counts only — never who.
create or replace function public.seller_tryon_insights(p_seller_id uuid, p_days integer default 30)
returns table (product_id uuid, title text, tryons integer, shoppers integer, buyers integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.can_see_seller(p_seller_id) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  return query
  with tried as (
    select j.product_id, j.user_id, min(j.created_at) as first_try, count(*) as n
    from public.tryon_jobs j
    join public.products p on p.id = j.product_id
    where p.seller_id = p_seller_id
      and j.status = 'succeeded'
      and j.created_at > now() - make_interval(days => least(greatest(p_days, 1), 366))
    group by j.product_id, j.user_id
  )
  select t.product_id, p.title,
         sum(t.n)::integer,
         count(*)::integer,
         count(*) filter (where exists (
           select 1 from public.order_items i
           join public.seller_orders so on so.id = i.seller_order_id
           where i.product_id = t.product_id and i.customer_id = t.user_id
             and i.order_id is not null and so.created_at >= t.first_try
             and so.status not in ('pending_payment', 'cancelled')))::integer
  from tried t
  join public.products p on p.id = t.product_id
  group by t.product_id, p.title
  order by 3 desc;
end $$;
grant execute on function public.seller_tryon_insights(uuid, integer) to authenticated;
