-- Scheduled jobs (pg_cron + pg_net). Each part is skipped where an extension
-- is not available, so the migrations also run on a plain Postgres.
--
--  * every 5 min: cancel unpaid orders whose 15-minute hold ran out;
--  * every 5 min: send pending refunds (refund Edge Function);
--  * hourly: delete expired / removed try-on photos (tryon-cleanup).
--
-- Calls to Edge Functions read the gateway URL and service key from
-- private.settings, filled in per environment (see docs/backend.md).

create table if not exists private.settings (
  key text primary key,
  value text not null
);
alter table private.settings enable row level security;
revoke all on private.settings from anon, authenticated;

create or replace function private.invoke_edge_function(p_name text, p_body jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  base text := (select value from private.settings where key = 'functions_url');
  service_key text := (select value from private.settings where key = 'service_role_key');
begin
  if base is null or service_key is null
     or not exists (select 1 from pg_extension where extname = 'pg_net') then
    return;
  end if;
  perform net.http_post(
    url := base || '/' || p_name,
    body := p_body,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key));
end $$;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  end if;
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('release-expired-reservations', '*/5 * * * *',
      'select public.release_expired_reservations()');
    perform cron.schedule('refund-sweep', '*/5 * * * *',
      $job$select private.invoke_edge_function('refund', '{"sweep": true}'::jsonb)$job$);
    perform cron.schedule('tryon-cleanup', '17 * * * *',
      $job$select private.invoke_edge_function('tryon-cleanup', '{}'::jsonb)$job$);
  end if;
end $$;
