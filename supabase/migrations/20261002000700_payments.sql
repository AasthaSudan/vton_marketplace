-- Payments, refunds and webhooks. "A payment only counts once Clothsy
-- confirms it" (Blueprint fig. 19) and "no double charges": every confirm,
-- refund and webhook is idempotent and leaves an append-only trail.

create type public.payment_provider as enum ('razorpay', 'mock');
create type public.payment_state as enum ('created', 'captured', 'failed', 'refunded');
create type public.refund_status as enum ('pending', 'processing', 'processed', 'failed');

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  customer_id uuid,
  provider public.payment_provider not null,
  -- Razorpay order_... (created by the create-order function)
  provider_order_id text not null unique,
  -- Razorpay pay_... once a payment is captured
  provider_payment_id text unique,
  amount integer not null check (amount > 0),
  currency text not null default 'INR',
  state public.payment_state not null default 'created',
  signature_verified_at timestamptz,
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One live payment intent per order.
create unique index payments_one_active on public.payments (order_id)
  where state in ('created', 'captured');

create trigger payments_updated_at before update on public.payments
  for each row execute function private.set_updated_at();

create table public.payment_events (
  id bigserial primary key,
  payment_id uuid references public.payments (id) on delete cascade,
  order_id uuid references public.orders (id) on delete cascade,
  event_type text not null,
  provider_payment_id text,
  amount integer,
  source text not null
    check (source in ('create_order', 'client_verify', 'webhook', 'system', 'refund')),
  payload jsonb,
  created_at timestamptz not null default now()
);

create trigger payment_events_append_only before update or delete on public.payment_events
  for each row execute function private.append_only();

-- Refund outbox: the order functions write rows, the `refund` Edge Function
-- sends them to the payment provider and records the outcome.
create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  seller_order_id uuid references public.seller_orders (id) on delete cascade,
  payment_id uuid references public.payments (id),
  -- The gateway payment to refund (a duplicate payment has its own id).
  provider_payment_id text,
  customer_id uuid,
  amount integer not null check (amount > 0),
  reason text not null,
  status public.refund_status not null default 'pending',
  provider_refund_id text unique,
  attempts integer not null default 0,
  last_error text,
  requested_by uuid,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

-- At most one refund per cancelled seller order, and one per late payment.
create unique index refunds_one_per_seller_order on public.refunds (seller_order_id)
  where seller_order_id is not null;
create unique index refunds_one_late_payment on public.refunds (provider_payment_id)
  where reason in ('late_payment', 'duplicate_payment');

create table public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  event_type text not null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  attempts integer not null default 0,
  last_error text,
  unique (provider, event_id)
);

-- Only processing bookkeeping may change on a stored webhook.
create or replace function private.webhook_events_guard()
returns trigger language plpgsql as $$
begin
  if new.provider is distinct from old.provider
     or new.event_id is distinct from old.event_id
     or new.payload is distinct from old.payload then
    raise exception 'APPEND_ONLY' using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger webhook_events_guard before update on public.webhook_events
  for each row execute function private.webhook_events_guard();

alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.refunds enable row level security;
alter table public.webhook_events enable row level security;

revoke insert, update, delete on public.payments, public.payment_events,
  public.refunds, public.webhook_events from anon, authenticated;

create policy "payments: own" on public.payments
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_staff(array['finance', 'support']::public.app_role[])
  );

create policy "payment_events: finance" on public.payment_events
  for select to authenticated
  using (private.is_staff(array['finance']::public.app_role[]));

create policy "refunds: own" on public.refunds
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_staff(array['finance', 'support']::public.app_role[])
  );

-- webhook_events: service role only (no policies).
