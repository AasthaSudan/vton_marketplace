-- Reference data for local development: launch coupons and the PIN codes
-- Clothsy delivers to. Hand-written (the catalogue is generated).

insert into public.coupons (code, kind, percent_bps) values
  ('CLOTHSY10', 'percent', 1000),
  ('WELCOME10', 'percent', 1000),
  ('LUXURY20', 'percent', 2000)
on conflict (code) do nothing;

insert into public.coupons (code, kind, percent_bps, first_order_only) values
  ('FIRST15', 'percent', 1500, true)
on conflict (code) do nothing;

-- Same launch cities as the app's mock; 700001 is prepaid-only so the COD
-- path can be tried out.
insert into public.serviceable_pincodes (pin_code, city, state, cod_available, eta_days) values
  ('110001', 'New Delhi', 'Delhi', true, 2),
  ('110024', 'New Delhi', 'Delhi', true, 2),
  ('110057', 'New Delhi', 'Delhi', true, 2),
  ('122001', 'Gurugram', 'Haryana', true, 2),
  ('122002', 'Gurugram', 'Haryana', true, 2),
  ('400001', 'Mumbai', 'Maharashtra', true, 2),
  ('400050', 'Bandra, Mumbai', 'Maharashtra', true, 2),
  ('560001', 'Bengaluru', 'Karnataka', true, 2),
  ('560038', 'Indiranagar, Bengaluru', 'Karnataka', true, 2),
  ('500001', 'Hyderabad', 'Telangana', true, 3),
  ('600001', 'Chennai', 'Tamil Nadu', true, 3),
  ('700001', 'Kolkata', 'West Bengal', false, 3),
  ('380001', 'Ahmedabad', 'Gujarat', true, 3),
  ('302001', 'Jaipur', 'Rajasthan', true, 3)
on conflict (pin_code) do nothing;
