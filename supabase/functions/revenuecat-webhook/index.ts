// Supabase Edge Function: webhook RevenueCat → public.subscriptions.
// NONAKTIF sampai secret diisi:
//   supabase secrets set REVENUECAT_WEBHOOK_SECRET=<nilai acak panjang> REVENUECAT_ENTITLEMENT=premium
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
// Di dashboard RevenueCat: Integrations → Webhooks → URL
//   https://<project>.supabase.co/functions/v1/revenuecat-webhook
//   Authorization header: Bearer <REVENUECAT_WEBHOOK_SECRET>
// SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY disediakan otomatis oleh Supabase
// (service role HANYA ada di server, tidak pernah di aplikasi/CMS).
import { createClient } from 'npm:@supabase/supabase-js@2';
import { mapEvent } from './mapping.ts';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!secret) return json(503, { error: 'webhook_disabled' });
  if (req.method !== 'POST') return json(405, { error: 'method_not_allowed' });
  const auth = req.headers.get('authorization') ?? '';
  if (!safeEqual(auth, `Bearer ${secret}`)) return json(401, { error: 'unauthorized' });

  let body: { event?: Record<string, unknown> };
  try { body = await req.json(); } catch { return json(400, { error: 'invalid_json' }); }
  const event = body?.event;
  if (!event || typeof event !== 'object') return json(400, { error: 'missing_event' });

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });
  const uid = String(event.app_user_id ?? '').toLowerCase();
  const { data: existing } = await db.from('subscriptions')
    .select('source, is_premium, expires_at').eq('user_id', uid).maybeSingle();

  const update = mapEvent(event, existing, Deno.env.get('REVENUECAT_ENTITLEMENT') ?? 'premium');
  if (!update) return json(200, { ignored: true });

  const { data: profile } = await db.from('profiles').select('id').eq('id', update.user_id).maybeSingle();
  if (!profile) return json(200, { ignored: true, reason: 'unknown_user' });

  const { error } = await db.from('subscriptions').upsert(update, { onConflict: 'user_id' });
  if (error) return json(500, { error: error.message });   // RevenueCat akan mengirim ulang
  return json(200, { ok: true });
});
