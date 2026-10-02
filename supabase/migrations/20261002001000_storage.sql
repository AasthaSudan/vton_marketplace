-- Storage buckets. Product images are public; shopper try-on photos and
-- results are private, and each shopper can only reach their own folder
-- (<user id>/...). Created in SQL so a hosted project gets the same setup.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('catalog', 'catalog', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('tryon-photos', 'tryon-photos', false, 8388608,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('tryon-results', 'tryon-results', false, 8388608,
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

grant execute on function private.try_uuid(text) to authenticated;

-- Catalogue images: sellers upload under sellers/<seller id>/...
create policy "catalog: sellers upload their own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'catalog'
    and (storage.foldername(name))[1] = 'sellers'
    and (private.is_seller_member(private.try_uuid((storage.foldername(name))[2]))
         or private.is_staff(array['ops', 'moderator']::public.app_role[]))
  );

create policy "catalog: sellers change their own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'catalog'
    and (private.is_seller_member(private.try_uuid((storage.foldername(name))[2]))
         or private.is_staff(array['ops', 'moderator']::public.app_role[]))
  );

create policy "catalog: sellers delete their own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'catalog'
    and (private.is_seller_member(private.try_uuid((storage.foldername(name))[2]))
         or private.is_staff(array['ops', 'moderator']::public.app_role[]))
  );

-- Try-on photos: only the shopper, and uploading needs their consent.
create policy "tryon-photos: read own"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tryon-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "tryon-photos: upload own with consent"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'tryon-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and private.has_tryon_consent((select auth.uid()))
  );

create policy "tryon-photos: delete own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tryon-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Try-on results are written by the tryon-run function (service role).
create policy "tryon-results: read own"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'tryon-results'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "tryon-results: delete own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'tryon-results'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
