// Edge Function "parse-nfce": recebe {"qr": "<url ou chave>"} e devolve os itens da NFC-e de SP.
// Contrato: ver lib/services/nota_fiscal_service.dart.
// Deploy: supabase functions deploy parse-nfce   (mantém verificação de JWT: o app envia a anon key)
import { consultarNfce } from './nfce.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (b: unknown) =>
  new Response(JSON.stringify(b), { headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'Use POST.' });
  let body: { qr?: string; debug?: boolean } = {};
  try { body = await req.json(); } catch { /* vazio */ }
  if (!body.qr) return json({ ok: false, error: 'Campo "qr" ausente.' });
  return json(await consultarNfce(body.qr, fetch, body.debug === true));
});
