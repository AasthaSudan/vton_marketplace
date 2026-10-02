-- Product search: full text plus trigram similarity so typos still find
-- things ("blazr" → blazer). Brand names are searchable too.

create or replace function private.products_search_refresh()
returns trigger language plpgsql as $$
declare
  seller_name text;
begin
  select s.name into seller_name from public.sellers s where s.id = new.seller_id;
  new.search_text := lower(concat_ws(' ',
    new.title, seller_name, new.category, array_to_string(new.tags, ' ')));
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('english', concat_ws(' ',
      seller_name, new.category, array_to_string(new.tags, ' '))), 'B') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'C');
  return new;
end $$;

create trigger products_search before insert or update of
  title, description, category, tags, seller_id
  on public.products
  for each row execute function private.products_search_refresh();

-- A renamed brand refreshes its products' search fields.
create or replace function private.sellers_search_cascade()
returns trigger language plpgsql as $$
begin
  if new.name is distinct from old.name then
    update public.products set title = title where seller_id = new.id;
  end if;
  return null;
end $$;

create trigger sellers_search_cascade after update of name on public.sellers
  for each row execute function private.sellers_search_cascade();

create index products_search_vector on public.products using gin (search_vector);
create index products_search_trgm on public.products
  using gin (search_text extensions.gin_trgm_ops);

-- Live products matching [q], best first. SECURITY INVOKER: row level
-- security still decides what the caller can see. Returns whole product rows
-- so PostgREST can embed sellers and variants.
create or replace function public.search_products(
  q text,
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.products
language sql stable set search_path = public, extensions as $$
  with query as (
    select lower(trim(q)) as text,
           websearch_to_tsquery('english', coalesce(q, '')) as ts
  )
  select p.*
  from public.products p, query
  where length(query.text) > 0
    and p.status = 'live'
    and (
      p.search_vector @@ query.ts
      or p.search_text ilike '%' || query.text || '%'
      or word_similarity(query.text, p.search_text) > 0.45
    )
  order by
    ts_rank(p.search_vector, query.ts) desc,
    word_similarity(query.text, p.search_text) desc,
    p.sort_rank
  limit least(greatest(p_limit, 1), 50)
  offset greatest(p_offset, 0);
$$;

grant execute on function public.search_products(text, integer, integer) to anon, authenticated;
