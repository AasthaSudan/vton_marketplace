-- Service users connect with the local POSTGRES_PASSWORD (as in Supabase's
-- self-hosting setup). Local development only. (supabase_functions_admin is
-- only created by Supabase's database-webhooks script, which Clothsy skips.)
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
