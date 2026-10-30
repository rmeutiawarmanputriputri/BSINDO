// Pemetaan event RevenueCat → baris public.subscriptions.
// Murni (tanpa Deno/Supabase) agar bisa diuji di Node: `node --experimental-strip-types mapping.test.ts`.
// Asumsi: aplikasi memanggil Purchases.logIn(<supabase user id>) sehingga
// event.app_user_id = UUID pengguna Supabase.

export type RcEvent = {
  type?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  product_id?: string;
  expiration_at_ms?: number | null;
  purchased_at_ms?: number | null;
  entitlement_ids?: string[] | null;
};

export type ExistingSub = { source: string; is_premium: boolean; expires_at: string | null } | null;

export type SubUpdate = {
  user_id: string;
  is_premium: boolean;
  status: 'active' | 'expired' | 'cancelled' | 'billing_issue';
  source: 'revenuecat';
  plan: string | null;
  started_at: string | null;
  expires_at: string | null;
  rc_app_user_id: string;
  rc_product_id: string | null;
  rc_last_event: string;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const GRANT = new Set(['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE', 'NON_RENEWING_PURCHASE', 'SUBSCRIPTION_EXTENDED', 'TEMPORARY_ENTITLEMENT_GRANT']);
const KEEP_UNTIL_EXPIRY = new Set(['CANCELLATION', 'BILLING_ISSUE', 'SUBSCRIPTION_PAUSED']);

const iso = (ms?: number | null) => (ms ? new Date(ms).toISOString() : null);

/** null = abaikan event (TEST, TRANSFER, pengguna bukan UUID, dsb.). */
export function mapEvent(e: RcEvent, existing: ExistingSub, entitlement: string, now = Date.now()): SubUpdate | null {
  const type = (e.type ?? '').toUpperCase();
  const uid = e.app_user_id ?? '';
  if (!UUID.test(uid)) return null;
  if (e.entitlement_ids && e.entitlement_ids.length && !e.entitlement_ids.includes(entitlement)) return null;

  const base = {
    user_id: uid.toLowerCase(), source: 'revenuecat' as const, plan: e.product_id ?? null,
    rc_app_user_id: uid, rc_product_id: e.product_id ?? null, rc_last_event: type,
    started_at: iso(e.purchased_at_ms), expires_at: iso(e.expiration_at_ms),
  };
  const notExpired = !e.expiration_at_ms || e.expiration_at_ms > now;

  if (GRANT.has(type)) {
    return { ...base, is_premium: notExpired, status: notExpired ? 'active' : 'expired' };
  }
  if (KEEP_UNTIL_EXPIRY.has(type)) {
    // Akses tetap sampai tanggal kedaluwarsa; status hanya penanda.
    return { ...base, is_premium: notExpired, status: notExpired ? 'active' : (type === 'BILLING_ISSUE' ? 'billing_issue' : 'cancelled') };
  }
  if (type === 'EXPIRATION') {
    // Premium manual tanpa batas yang diberikan admin tidak dicabut oleh RevenueCat.
    if (existing && existing.source === 'manual' && existing.is_premium && !existing.expires_at) return null;
    return { ...base, is_premium: false, status: 'expired' };
  }
  return null; // TEST, TRANSFER, SUBSCRIBER_ALIAS, dll.
}
