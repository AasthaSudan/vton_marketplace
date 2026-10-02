import { assert, assertEquals } from '@std/assert';
import { hmacSha256Hex, timingSafeEqual } from './hmac.ts';

Deno.test('HMAC-SHA256 matches RFC 4231 test case 2', async () => {
  assertEquals(
    await hmacSha256Hex('Jefe', 'what do ya want for nothing?'),
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
  );
});

Deno.test('timingSafeEqual compares whole strings', () => {
  assert(timingSafeEqual('abc', 'abc'));
  assert(!timingSafeEqual('abc', 'abd'));
  assert(!timingSafeEqual('abc', 'abcd'));
  assert(!timingSafeEqual('', 'a'));
});
