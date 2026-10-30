import assert from 'node:assert/strict';
import { mapEvent } from './mapping.ts';
const U = '0f0e0d0c-0000-4000-8000-000000000001';
const now = Date.UTC(2026, 9, 30);
const fut = now + 86400000, past = now - 1000;
let n = 0; const ok = (name: string, f: () => void) => { f(); n++; console.log('LULUS', name); };

ok('purchase aktif', () => { const r = mapEvent({ type: 'INITIAL_PURCHASE', app_user_id: U, expiration_at_ms: fut, product_id: 'p' }, null, 'premium', now)!; assert.equal(r.is_premium, true); assert.equal(r.status, 'active'); });
ok('renewal kedaluwarsa', () => { const r = mapEvent({ type: 'RENEWAL', app_user_id: U, expiration_at_ms: past }, null, 'premium', now)!; assert.equal(r.is_premium, false); });
ok('cancel tetap akses s.d. expiry', () => { const r = mapEvent({ type: 'CANCELLATION', app_user_id: U, expiration_at_ms: fut }, null, 'premium', now)!; assert.equal(r.is_premium, true); });
ok('expiration mencabut', () => { const r = mapEvent({ type: 'EXPIRATION', app_user_id: U }, { source: 'revenuecat', is_premium: true, expires_at: null }, 'premium', now)!; assert.equal(r.is_premium, false); assert.equal(r.status, 'expired'); });
ok('expiration tidak mencabut premium manual tanpa batas', () => { assert.equal(mapEvent({ type: 'EXPIRATION', app_user_id: U }, { source: 'manual', is_premium: true, expires_at: null }, 'premium', now), null); });
ok('app_user_id bukan UUID diabaikan', () => { assert.equal(mapEvent({ type: 'INITIAL_PURCHASE', app_user_id: '$RCAnonymousID:abc' }, null, 'premium', now), null); });
ok('entitlement lain diabaikan', () => { assert.equal(mapEvent({ type: 'INITIAL_PURCHASE', app_user_id: U, entitlement_ids: ['lain'] }, null, 'premium', now), null); });
ok('event TEST diabaikan', () => { assert.equal(mapEvent({ type: 'TEST', app_user_id: U }, null, 'premium', now), null); });
console.log(`${n} uji LULUS`);
