"""Phase 1 exit check against the local Docker stack (scripts/backend.sh e2e).

Goes through the gateway with the same calls the app's Supabase
repositories make: sign-in, onboarding, search, PIN check, Try-On, a
two-brand bag with a coupon, COD and prepaid orders, cancelling one brand
and its refund. Run it on a fresh stack (scripts/backend.sh reset).
"""
import json
import os
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.environ.get('CLOTHSY_API_URL', 'http://127.0.0.1:54321')
env = {}
for line in open(os.path.join(ROOT, 'supabase/.env')).read().splitlines():
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        env[k] = v
ANON, SERVICE = env['ANON_KEY'], env['SERVICE_ROLE_KEY']
failures = []


def call(method, path, body=None, token=None, headers=None, raw=None, ctype=None):
    # Like supabase-js: guests send the anon key as their bearer token.
    h = {'apikey': ANON, 'Authorization': f'Bearer {token or ANON}'}
    if headers:
        h.update(headers)
    data = None
    if raw is not None:
        data, h['Content-Type'] = raw, ctype
    elif body is not None:
        data, h['Content-Type'] = json.dumps(body).encode(), 'application/json'
    req = urllib.request.Request(B + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            txt = r.read().decode()
            return r.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        txt = e.read().decode()
        try:
            return e.code, json.loads(txt)
        except ValueError:
            return e.code, txt


def sql(q):
    out = subprocess.run(
        ['docker', 'compose', '--env-file', 'supabase/.env', 'exec', '-T', 'db',
         'psql', '-U', 'postgres', '-At', '-c', q],
        cwd=ROOT, capture_output=True, text=True, check=True)
    return out.stdout.strip()


def check(cond, msg, extra=None):
    print(('  PASS ' if cond else '  FAIL ') + msg
          + ('' if cond or extra is None else f'  -> {extra}'))
    if not cond:
        failures.append(msg)
    return cond


def step(title):
    print(f'\n== {title}')


def sign_in(phone):
    call('POST', '/auth/v1/otp', {'phone': phone})
    s, d = call('POST', '/auth/v1/verify', {'type': 'sms', 'phone': phone, 'token': '123456'})
    if s != 200:
        sys.exit(f'sign-in failed for {phone}: {s} {d}')
    return d['access_token'], d['user']['id']


def png(w=4, h=4):
    rows = b''.join(b'\x00' + b'\x80\x40\xc0' * w for _ in range(h))

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def stock(sku):
    return int(sql(f"select stock from public.product_variants where sku = '{sku}'"))


# ---------------------------------------------------------------------------
step('1. Test-OTP sign-in')
s, d = call('POST', '/auth/v1/verify', {'type': 'sms', 'phone': '+919999900001', 'token': '000000'})
check(s >= 400, 'a wrong code is refused', (s, d))
A, a_id = sign_in('+919999900001')
Bt, b_id = sign_in('+919999900003')
check(bool(A) and bool(Bt), 'two shoppers signed in with test OTPs')
s, prof = call('GET', '/rest/v1/profiles?select=id,member_tier', token=A)
check(len(prof) == 1 and prof[0]['id'] == a_id, 'shopper sees only their own profile', prof)

step('2. Style onboarding saved')
prefs = {'categories': ['Tops', 'Outerwear'], 'looks': ['minimal'], 'brand_ids': [],
         'budget': 'mid', 'completed_at': '2026-10-02T14:00:00Z'}
call('PATCH', f'/rest/v1/profiles?id=eq.{a_id}',
     {'full_name': 'Test Shopper', 'style_prefs': prefs}, token=A)
s, prof = call('GET', '/rest/v1/profiles?select=full_name,style_prefs', token=A)
check(prof[0]['style_prefs'] == prefs and prof[0]['full_name'] == 'Test Shopper',
      'preferences persisted in profiles', prof)
s, d = call('PATCH', f'/rest/v1/profiles?id=eq.{a_id}', {'member_tier': 'VIP'}, token=A)
check(s == 403, 'shopper cannot change their own tier', (s, d))

step('3. Search "blazr"')
s, hits = call('POST', '/rest/v1/rpc/search_products?select=handle', {'q': 'blazr'})
handles = [h['handle'] for h in hits] if isinstance(hits, list) else hits
check(isinstance(hits, list) and any('blazer' in h for h in handles),
      'typo finds the blazers (as a guest)', handles)

step('4. PDP PIN check')
s, pin = call('POST', '/rest/v1/rpc/check_pin_serviceability', {'p_pin': '110001'})
check(s == 200 and pin['serviceable'] and pin['cod_available'] and pin['eta_days'] > 0,
      '110001 serviceable with COD', pin)
s, pin = call('POST', '/rest/v1/rpc/check_pin_serviceability', {'p_pin': '999999'})
check(s == 200 and not pin['serviceable'], 'unknown PIN is not serviceable', pin)

# ---------------------------------------------------------------------------
step('5. Try on with your own photo')
s, products = call('GET', '/rest/v1/products?select=id,handle,product_variants(id,sku)'
                   '&is_tryon_eligible=is.true&limit=1')
prod = products[0]
variant = prod['product_variants'][0]
s, st = call('POST', '/rest/v1/rpc/get_tryon_status', {}, token=A)
credits_before = st['credits']
check(not st['consented'], 'no consent until the shopper gives it', st)
path = f'{a_id}/{uuid.uuid4()}.png'
s, d = call('POST', f'/storage/v1/object/tryon-photos/{path}', raw=png(), ctype='image/png', token=A)
s2, d2 = call('POST', '/rest/v1/tryon_photos', {'storage_path': path, 'label': 'My photo'},
              token=A, headers={'Prefer': 'return=representation'})
check(s >= 400 or s2 >= 400, 'no photo is kept without consent', (s, d, s2, d2))
if s < 400:
    call('DELETE', f'/storage/v1/object/tryon-photos/{path}', token=A)

s, d = call('POST', '/rest/v1/rpc/set_tryon_consent', {'p_granted': True}, token=A)
check(s == 200, 'consent recorded', (s, d))
path = f'{a_id}/{uuid.uuid4()}.png'
s, d = call('POST', f'/storage/v1/object/tryon-photos/{path}', raw=png(), ctype='image/png', token=A)
check(s == 200, 'photo uploaded to the private bucket, own folder', (s, d))
s, d = call('POST', f'/storage/v1/object/tryon-photos/{b_id}/{uuid.uuid4()}.png',
            raw=png(), ctype='image/png', token=A)
check(s >= 400, "cannot upload into another shopper's folder", (s, d))
s, rows = call('POST', '/rest/v1/tryon_photos', {'storage_path': path, 'label': 'My photo'},
               token=A, headers={'Prefer': 'return=representation'})
check(s == 201, 'photo row saved with an expiry', (s, rows))
photo_id = rows[0]['id']
s, d = call('GET', f'/storage/v1/object/authenticated/tryon-photos/{path}', token=Bt)
check(s >= 400, 'another shopper cannot read the photo', s)
s, d = call('GET', '/rest/v1/tryon_photos?select=id', token=Bt)
check(d == [], "another shopper sees none of the photo rows", d)

run = {'action': 'run', 'product_id': prod['id'], 'variant_id': variant['id'], 'photo_id': photo_id}
s, job = call('POST', '/functions/v1/tryon-run', run, token=A)
check(s == 200 and bool(job.get('job_id')), 'try-on job started', (s, job))
status = job.get('status')
for _ in range(10):
    if status in ('succeeded', 'failed') or not job.get('job_id'):
        break
    time.sleep(1)
    s, job = call('POST', '/functions/v1/tryon-run', {'action': 'poll', 'job_id': job['job_id']}, token=A)
    status = job.get('status')
check(status == 'succeeded' and bool(job.get('result_url') or job.get('result_path')),
      'preview ready', job)
s, st = call('POST', '/rest/v1/rpc/get_tryon_status', {}, token=A)
check(st['credits'] == credits_before - 1,
      f'one credit used ({credits_before} -> {st["credits"]})', st)
s, again = call('POST', '/functions/v1/tryon-run', run, token=A)
s, st2 = call('POST', '/rest/v1/rpc/get_tryon_status', {}, token=A)
check(again.get('cached') is True and st2['credits'] == st['credits'],
      'same look again is cached and free', again)
s, d = call('POST', '/functions/v1/tryon-run', run)
check(s == 401, 'try-on needs a signed-in shopper', (s, d))

# ---------------------------------------------------------------------------
step('6. Address + two-brand bag with LUXURY20')
s, addr = call('POST', '/rest/v1/addresses',
               {'name': 'Test Shopper', 'phone': '+919999900001', 'line1': '1 MG Road',
                'city': 'New Delhi', 'state': 'Delhi', 'pin_code': '110001'},
               token=A, headers={'Prefer': 'return=representation'})
check(s == 201 and addr[0]['is_default'], 'first address saved as default', (s, addr))
address_id = addr[0]['id']

s, variants = call('GET', '/rest/v1/product_variants?select=id,sku,price,stock,seller_id'
                   '&stock=gt.2&order=price.asc')
by_seller = {}
for v in variants:
    by_seller.setdefault(v['seller_id'], []).append(v)
sellers = list(by_seller)[:2]
check(len(sellers) == 2, 'catalogue has two brands with stock')


def quote(lines, bps=2000):
    # The app's CartSummary maths: ₹150 shipping per brand under ₹1,999,
    # percent coupons rounded half up on the goods.
    goods = shipping = 0
    for seller in {v['seller_id'] for v, _ in lines}:
        sub = sum(v['price'] * q for v, q in lines if v['seller_id'] == seller)
        goods += sub
        shipping += 15000 if sub < 199900 else 0
    return goods + shipping - (goods * bps + 5000) // 10000


def place(lines, method, key=None, expected=None):
    return call('POST', '/functions/v1/create-order', {
        'items': [{'variant_id': v['id'], 'quantity': q} for v, q in lines],
        'address_id': address_id, 'payment_method': method, 'payment_label': method.upper(),
        'coupon_code': 'luxury20', 'idempotency_key': key or str(uuid.uuid4()),
        'expected_total': quote(lines) if expected is None else expected}, token=A)


cheap = [(by_seller[sellers[0]][0], 1), (by_seller[sellers[1]][0], 1)]
s, d = place(cheap, 'cod', expected=quote(cheap) + 100)
check(s == 409 and 'PRICE_CHANGED' in json.dumps(d), 'a stale total is refused (PRICE_CHANGED)', (s, d))

step('7. COD order')
before = {v['sku']: stock(v['sku']) for v, _ in cheap}
s, cod = place(cheap, 'cod')
check(s == 200 and cod.get('payment_status') == 'cod' and cod.get('payment') is None,
      'COD order placed', (s, cod))
check(cod.get('amount') == quote(cheap),
      f'server total matches the bag ({quote(cheap)} paise, coupon is case-insensitive)', cod)
check(all(stock(v['sku']) == before[v['sku']] - 1 for v, _ in cheap), 'stock taken for both brands')
s, so = call('GET', f'/rest/v1/seller_orders?order_id=eq.{cod["order_id"]}&select=reference,total', token=A)
check(len(so) == 2 and sum(x['total'] for x in so) == cod['amount'],
      'split into two seller orders that add up', so)
s, d = call('GET', f'/rest/v1/orders?id=eq.{cod["order_id"]}&select=id', token=Bt)
check(d == [], 'another shopper cannot see the order', d)
s, d = call('PATCH', f'/rest/v1/orders?id=eq.{cod["order_id"]}', {'grand_total': 1}, token=A)
check(s >= 400, 'shopper cannot edit their order', (s, d))

step('8. Prepaid order: pending -> paid')
dear = [(by_seller[sellers[0]][-1], 1), (by_seller[sellers[1]][-1], 1)]
before = {v['sku']: stock(v['sku']) for v, _ in dear}
key = str(uuid.uuid4())
s, pre = place(dear, 'upi', key=key)
if not check(s == 200 and pre.get('payment_status') == 'pending' and bool(pre.get('payment')),
             'online order pending with a gateway order', (s, pre)):
    sys.exit(f'\n{len(failures)} FAILED: ' + '; '.join(failures))
check(all(stock(v['sku']) == before[v['sku']] - 1 for v, _ in dear), 'stock held while paying')
s, replay = place(dear, 'upi', key=key)
check(replay.get('order_id') == pre['order_id']
      and (replay.get('payment') or {}).get('provider_order_id') == pre['payment']['provider_order_id'],
      'retrying checkout returns the same order and gateway order', replay)
gw = pre['payment']['provider_order_id']
s, d = call('POST', '/functions/v1/verify-payment', {'order_id': pre['order_id'],
            'provider_order_id': gw, 'provider_payment_id': 'not_a_mock_payment',
            'signature': 'x'}, token=A)
check(s >= 400, 'a bad payment signature does not confirm', (s, d))
verify = {'order_id': pre['order_id'], 'provider_order_id': gw,
          'provider_payment_id': f'pay_mock_{uuid.uuid4().hex[:14]}', 'signature': ''}
s, d = call('POST', '/functions/v1/verify-payment', verify, token=Bt)
check(s == 404, "another shopper cannot confirm someone else's order", (s, d))
s, d = call('POST', '/functions/v1/verify-payment', verify, token=A)
check(s == 200 and d.get('payment_status') == 'paid', 'payment verified -> paid', (s, d))
s, d = call('POST', '/functions/v1/verify-payment', verify, token=A)
check(s == 200 and d.get('payment_status') == 'paid', 'verifying again is a no-op', (s, d))
check(sql(f"select count(*) from public.payments where order_id = '{pre['order_id']}'"
          " and state = 'captured'") == '1', 'exactly one captured payment')

step('9. Cancel one brand -> refund for exactly that part, stock restored')
s, parts = call('GET', f'/rest/v1/seller_orders?order_id=eq.{pre["order_id"]}'
                '&select=id,seller_id,total,status&order=position', token=A)
part = parts[0]
sku = next(v['sku'] for v, _ in dear if v['seller_id'] == part['seller_id'])
held = stock(sku)
s, d = call('POST', '/rest/v1/rpc/cancel_seller_order', {'p_order_id': pre['order_id'],
            'p_seller_order_id': part['id'], 'p_reason': 'Changed my mind'}, token=A)
check(s in (200, 204), 'seller part cancelled', (s, d))
refund = sql(f"select amount || '|' || status from public.refunds where seller_order_id = '{part['id']}'")
check(refund.split('|')[0] == str(part['total']),
      f'refund queued for exactly that part ({part["total"]} paise)', refund)
check(stock(sku) == held + 1, 'stock restored for that piece')
s, d = call('POST', '/rest/v1/rpc/cancel_seller_order', {'p_order_id': pre['order_id'],
            'p_seller_order_id': part['id'], 'p_reason': 'again'}, token=A)
check(sql(f"select count(*) from public.refunds where seller_order_id = '{part['id']}'") == '1',
      'cancelling twice queues no second refund', (s, d))
s, d = call('POST', '/functions/v1/refund', {'sweep': True}, token=A)
check(s in (401, 403), 'shoppers cannot run the refund sweep', (s, d))
# What the refund-sweep cron job runs: pg_net calls the function from
# Postgres with the service key kept in private.settings.
sql("""select private.invoke_edge_function('refund', '{"sweep": true}'::jsonb)""")
refund_sql = ("select status || '|' || coalesce(provider_refund_id, '') from public.refunds"
              f" where seller_order_id = '{part['id']}'")
for _ in range(20):
    refund = sql(refund_sql)
    if not refund.startswith('pending'):
        break
    time.sleep(1)
check(refund.startswith('processed|rfnd_mock_'),
      'the cron refund sweep sent it through the payment provider', refund)
s, o = call('GET', f'/rest/v1/orders?id=eq.{pre["order_id"]}&select=payment_status', token=A)
check(o[0]['payment_status'] == 'partially_refunded', 'order shows partially refunded', o)
s, parts = call('GET', f'/rest/v1/seller_orders?order_id=eq.{pre["order_id"]}'
                '&select=status&order=position', token=A)
check([p['status'] for p in parts] == ['cancelled', 'placed'], 'the other brand ships as normal', parts)

step('10. Try-on data deletion')
s, d = call('POST', '/rest/v1/rpc/delete_my_tryon_data', {}, token=A)
check(s == 200, 'delete my try-on data', (s, d))
s, rows = call('GET', '/rest/v1/tryon_photos?select=id', token=A)
check(rows == [], 'no photo rows left', rows)

print('\nALL PASSED' if not failures else f'\n{len(failures)} FAILED: ' + '; '.join(failures))
sys.exit(1 if failures else 0)
