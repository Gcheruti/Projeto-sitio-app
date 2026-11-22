// Lógica pura (sem APIs do Deno) da leitura de NFC-e de SP por QR Code.
// Testável com: node --experimental-strip-types --test supabase/functions/parse-nfce/

export interface Item {
  name: string;
  qty: number;
  unit_price: number | null;
  total: number | null;
  codigo?: string;
}
export interface Resultado {
  ok: boolean;
  error?: string;
  chave?: string;
  total?: number | null;
  items?: Item[];
  debug_html?: string;
}

const HOSTS_SP = new Set(['www.nfce.fazenda.sp.gov.br', 'nfce.fazenda.sp.gov.br']);

/** Dígito verificador da chave de acesso (módulo 11). */
export function chaveValida(chave: string): boolean {
  if (!/^\d{44}$/.test(chave)) return false;
  let soma = 0;
  let peso = 2;
  for (let i = 42; i >= 0; i--) {
    soma += Number(chave[i]) * peso;
    peso = peso === 9 ? 2 : peso + 1;
  }
  const resto = soma % 11;
  const dv = resto < 2 ? 0 : 11 - resto;
  return dv === Number(chave[43]);
}

/** Decide qual URL consultar. Nunca busca host que não seja da SEFAZ-SP (anti-SSRF). */
export function montarUrl(raw: string): { chave: string; url: string } | { erro: string } {
  const txt = raw.trim();
  const chave = txt.match(/\d{44}/)?.[0];
  if (!chave) return { erro: 'Não encontrei a chave de 44 dígitos no QR Code.' };
  if (!chaveValida(chave)) return { erro: 'Chave de acesso inválida (dígito verificador não confere).' };
  if (chave.slice(0, 2) !== '35') return { erro: 'Esta nota não é de São Paulo (UF diferente de 35).' };
  if (chave.slice(20, 22) !== '65') return { erro: 'Esta chave não é de NFC-e (modelo 65).' };

  if (/^https?:\/\//i.test(txt)) {
    try {
      const u = new URL(txt);
      if (u.protocol === 'https:' && HOSTS_SP.has(u.hostname)) return { chave, url: u.toString() };
    } catch { /* cai no padrão abaixo */ }
  }
  return { chave, url: `https://www.nfce.fazenda.sp.gov.br/qrcode?p=${chave}|3|1` };
}

function decode(s: string): string {
  return s
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCharCode(parseInt(n, 16)));
}
const texto = (h: string) => decode(h.replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ').trim();

/** "1.299,90" | "2,50" | "1.5" | "R$ 3,00" → número. */
export function numBR(s: string | undefined | null): number | null {
  if (!s) return null;
  const m = s.match(/\d[\d.,]*/);
  if (!m) return null;
  let t = m[0];
  if (t.includes(',')) t = t.replace(/\./g, '').replace(',', '.');
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

function span(bloco: string, cls: string): string {
  const re = new RegExp(`<span[^>]*class=["'][^"']*\\b${cls}\\b[^"']*["'][^>]*>([\\s\\S]*?)</span>`, 'i');
  const m = bloco.match(re);
  return m ? texto(m[1]) : '';
}

/** Layout HTML da consulta pública (tabela de itens com spans txtTit/Rqtd/RvlUnit/valor). */
export function parseHtml(html: string): { items: Item[]; total: number | null } {
  const items: Item[] = [];
  for (const bloco of html.split(/<tr[\s>]/i)) {
    if (!/class=["'][^"']*\btxtTit\b/i.test(bloco) || !/\bRqtd\b/i.test(bloco)) continue;
    const name = span(bloco, 'txtTit');
    if (!name) continue;
    const qty = numBR(span(bloco, 'Rqtd')) ?? 1;
    const unit = numBR(span(bloco, 'RvlUnit'));
    const total = numBR(span(bloco, 'valor')) ?? (unit != null ? Math.round(unit * qty * 100) / 100 : null);
    const codigo = span(bloco, 'RCod').match(/\d{3,}/)?.[0];
    items.push({ name, qty, unit_price: unit, total, ...(codigo ? { codigo } : {}) });
  }
  let total: number | null = null;
  const mt = html.match(/<span[^>]*class=["'][^"']*\btotalNumb\b[^"']*\btxtMax\b[^"']*["'][^>]*>([\s\S]*?)<\/span>/i);
  if (mt) total = numBR(texto(mt[1]));
  return { items, total };
}

/** Caso a SEFAZ devolva o XML da nota (nfeProc). */
export function parseXml(xml: string): { items: Item[]; total: number | null } {
  const tag = (b: string, t: string) => b.match(new RegExp(`<${t}>([\\s\\S]*?)</${t}>`))?.[1]?.trim();
  const items: Item[] = [];
  for (const m of xml.matchAll(/<det\b[\s\S]*?<\/det>/g)) {
    const b = m[0];
    const name = tag(b, 'xProd');
    if (!name) continue;
    const ean = tag(b, 'cEAN');
    items.push({
      name: decode(name),
      qty: Number(tag(b, 'qCom') ?? 1),
      unit_price: tag(b, 'vUnCom') != null ? Number(tag(b, 'vUnCom')) : null,
      total: tag(b, 'vProd') != null ? Number(tag(b, 'vProd')) : null,
      ...(ean && /^\d{8,14}$/.test(ean) ? { codigo: ean } : tag(b, 'cProd') ? { codigo: tag(b, 'cProd') } : {}),
    });
  }
  const vNF = tag(xml, 'vNF');
  return { items, total: vNF != null ? Number(vNF) : null };
}

type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

export async function consultarNfce(raw: string, fetchFn: FetchFn, debug = false): Promise<Resultado> {
  const alvo = montarUrl(raw);
  if ('erro' in alvo) return { ok: false, error: alvo.erro };

  let corpo: string;
  try {
    const res = await fetchFn(alvo.url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9',
      },
      signal: AbortSignal.timeout(20000),
    });
    if (res.url && !HOSTS_SP.has(new URL(res.url).hostname)) {
      return { ok: false, error: 'A consulta foi redirecionada para um endereço inesperado.', chave: alvo.chave };
    }
    if (!res.ok) return { ok: false, error: `A SEFAZ-SP respondeu ${res.status}.`, chave: alvo.chave };
    corpo = await res.text();
  } catch (e) {
    return { ok: false, error: `Não consegui falar com a SEFAZ-SP: ${e}`, chave: alvo.chave };
  }

  const r = /<nfeProc|<NFe\b|<det\b/.test(corpo) && !/class=["'][^"']*txtTit/i.test(corpo)
    ? parseXml(corpo)
    : parseHtml(corpo);

  if (r.items.length === 0) {
    const captcha = /captcha/i.test(corpo);
    return {
      ok: false,
      chave: alvo.chave,
      error: captcha
        ? 'A SEFAZ-SP pediu verificação (captcha). Use a foto do cupom.'
        : 'Não consegui ler os itens da página da SEFAZ-SP. Use a foto do cupom.',
      ...(debug ? { debug_html: corpo.slice(0, 6000) } : {}),
    };
  }
  const soma = Math.round(r.items.reduce((a, i) => a + (i.total ?? 0), 0) * 100) / 100;
  return { ok: true, chave: alvo.chave, total: r.total ?? soma, items: r.items };
}
