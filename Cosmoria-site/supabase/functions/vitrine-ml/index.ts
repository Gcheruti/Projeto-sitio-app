// Portal Cosmoria · vitrine do Mercado Livre (função "vitrine-ml" do Supabase).
// NÃO é a função do frete: esta só lê anúncios do Mercado Livre.
//
// O que ela faz (POST com JSON):
//   { acao: "ler", link }          lê o anúncio e devolve os dados para o painel revisar (não grava nada)
//   { acao: "atualizar", id }      lê de novo o anúncio do produto <id> da tabela vitrine_ml e grava
//   { acao: "atualizar_todos" }    atualiza todos os produtos com auto_atualizar = true
//   { acao: "link_autorizacao" }   devolve o link para autorizar o app no Mercado Livre (opcional)
// GET ?code=...&state=...          volta da autorização do Mercado Livre (guarda o refresh token)
//
// Quem pode chamar: uma conta administradora (token do login no cabeçalho Authorization)
// ou a atualização diária (cabeçalho x-cron-segredo igual a ajustes_ml.cron_segredo).
//
// De onde vêm os dados:
//   1) API oficial do Mercado Livre (precisa do Client ID e da Secret Key de um app criado em
//      developers.mercadolivre.com.br; o admin cola no painel e ficam em "Cosmoria".ajustes_ml,
//      ou nos segredos ML_CLIENT_ID / ML_CLIENT_SECRET da função).
//   2) Se a API não estiver disponível: lê a própria página do anúncio (dados JSON-LD e meta tags).
//      O Mercado Livre costuma bloquear essa leitura vinda de servidores, então a API é o caminho certo.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const env = (k: string) => (Deno.env.get(k) ?? "").trim();
const SUPABASE_URL = env("SUPABASE_URL");
const sb = createClient(SUPABASE_URL, env("SUPABASE_SERVICE_ROLE_KEY"), { db: { schema: "Cosmoria" }, auth: { persistSession: false } });
const API = "https://api.mercadolibre.com";
const URL_FUNCAO = SUPABASE_URL + "/functions/v1/vitrine-ml";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-segredo",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (dados: unknown, status = 200) => new Response(JSON.stringify(dados), { status, headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" } });

class Falha extends Error { constructor(msg: string, public status = 400) { super(msg); } }

// ---------------- ajustes guardados no banco ----------------
async function ajuste(chave: string): Promise<string> {
  const r = await sb.from("ajustes_ml").select("valor").eq("chave", chave).maybeSingle();
  return (r.data?.valor ?? "").trim();
}
async function gravarAjustes(m: Record<string, string>) {
  const linhas = Object.entries(m).map(([chave, valor]) => ({ chave, valor, atualizado_em: new Date().toISOString() }));
  const r = await sb.from("ajustes_ml").upsert(linhas);
  if (r.error) console.error("ajustes_ml:", r.error.message);
}

// ---------------- link do anúncio -> códigos ----------------
// Ex.: .../p/MLB33795714?...#...&wid=MLB4481788370  -> produto MLB33795714, anúncio MLB4481788370
//      produto.mercadolivre.com.br/MLB-4481788370-...  -> anúncio MLB4481788370
export function codigosDoLink(link: string) {
  const s = String(link || "").trim();
  const wid = /[?&#]wid=(MLB\d+)/i.exec(s)?.[1];
  const prod = /\/p\/(MLB\d+)/i.exec(s)?.[1];
  let item = wid;
  if (!item && !prod) { const m = /\bMLB-?(\d{6,})/i.exec(s); if (m) item = "MLB" + m[1]; }
  return { itemId: item ? item.toUpperCase() : null, produtoId: prod ? prod.toUpperCase() : null };
}

// ---------------- token do Mercado Livre ----------------
let tokenMemoria: { token: string; expira: number } | null = null;
async function chavesApp() {
  const id = env("ML_CLIENT_ID") || await ajuste("client_id");
  const segredo = env("ML_CLIENT_SECRET") || await ajuste("client_secret");
  return id && segredo ? { id, segredo } : null;
}
async function pedirToken(corpo: Record<string, string>) {
  const r = await fetch(API + "/oauth/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams(corpo).toString(),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.access_token) throw new Falha("Mercado Livre recusou as chaves do app: " + (j.message || j.error || r.status), 502);
  return j;
}
async function token(): Promise<string | null> {
  if (tokenMemoria && tokenMemoria.expira > Date.now() + 60_000) return tokenMemoria.token;
  const [salvo, expira] = [await ajuste("access_token"), Number(await ajuste("token_expira_em") || 0)];
  if (salvo && expira > Date.now() + 60_000) { tokenMemoria = { token: salvo, expira }; return salvo; }
  const app = await chavesApp();
  if (!app) return null;
  const refresh = await ajuste("refresh_token");
  let j;
  if (refresh) j = await pedirToken({ grant_type: "refresh_token", client_id: app.id, client_secret: app.segredo, refresh_token: refresh });
  else j = await pedirToken({ grant_type: "client_credentials", client_id: app.id, client_secret: app.segredo });
  const ate = Date.now() + (Number(j.expires_in) || 21600) * 1000;
  const grava: Record<string, string> = { access_token: j.access_token, token_expira_em: String(ate) };
  if (j.refresh_token) grava.refresh_token = j.refresh_token;
  await gravarAjustes(grava);
  tokenMemoria = { token: j.access_token, expira: ate };
  return j.access_token;
}

async function mlGet(caminho: string, tk: string) {
  const r = await fetch(API + caminho, { headers: { Authorization: "Bearer " + tk, Accept: "application/json" } });
  const j = await r.json().catch(() => null);
  if (!r.ok) {
    if (r.status === 401) { tokenMemoria = null; await gravarAjustes({ access_token: "", token_expira_em: "0" }); }
    throw new Falha("API do Mercado Livre (" + caminho.split("?")[0] + "): " + ((j && (j.message || j.error)) || r.status), r.status === 404 ? 404 : 502);
  }
  return j;
}

// ---------------- leitura pela API oficial ----------------
const centavos = (v: unknown) => (v == null || v === "" || isNaN(Number(v)) ? null : Math.round(Number(v) * 100));
const fotoGrande = (u: string) => String(u || "").replace(/^http:/, "https:").replace(/-[A-Z]\.(jpg|jpeg|png|webp)$/i, "-O.$1");

type Dados = {
  ml_item_id: string | null; ml_produto_id: string | null; permalink: string | null; nome: string;
  preco_centavos: number | null; preco_original_centavos: number | null; desconto_pct: number | null;
  fotos: string[]; descricao: string | null; atributos: { nome: string; valor: string }[];
  variacoes: { nome: string; opcoes: { valor: string; foto?: string | null; estoque?: number | null; preco_centavos?: number | null; ml_produto_id?: string; atual?: boolean }[] }[];
  condicao: string | null; estoque: number | null; vendidos: number | null; frete_gratis: boolean | null; ml_status: string | null; fonte: string;
};

function juntarAtributos(...listas: any[][]) {
  const vistos = new Set<string>(), out: { nome: string; valor: string }[] = [];
  const ignorar = new Set(["ITEM_CONDITION", "SELLER_SKU", "GTIN", "EAN", "UPC", "MPN", "PRODUCT_DATA_SOURCE", "IS_KIT", "IS_FLAMMABLE", "HAZMAT_TRANSPORTABILITY", "SHIPMENT_PACKING", "PACKAGE_DATA_SOURCE"]);
  for (const lista of listas) for (const a of lista || []) {
    const nome = String(a?.name || "").trim(), valor = String(a?.value_name ?? (a?.values?.[0]?.name ?? "")).trim();
    if (!nome || !valor || ignorar.has(a?.id) || /^PACKAGE_|^SELLER_PACKAGE_/.test(a?.id || "")) continue;
    const k = nome.toLowerCase(); if (vistos.has(k)) continue;
    vistos.add(k); out.push({ nome, valor });
  }
  return out;
}

function variacoesDoItem(item: any): Dados["variacoes"] {
  const grupos = new Map<string, Map<string, any>>();
  const fotoPorId = new Map<string, string>((item.pictures || []).map((p: any) => [p.id, fotoGrande(p.secure_url || p.url)]));
  for (const v of item.variations || []) for (const c of v.attribute_combinations || []) {
    const nome = String(c.name || "").trim(), valor = String(c.value_name || "").trim(); if (!nome || !valor) continue;
    if (!grupos.has(nome)) grupos.set(nome, new Map());
    const g = grupos.get(nome)!, ja = g.get(valor);
    const est = Number(v.available_quantity ?? 0);
    if (ja) { ja.estoque = (ja.estoque || 0) + est; continue; }
    g.set(valor, { valor, foto: fotoPorId.get(v.picture_ids?.[0]) || null, estoque: est, preco_centavos: centavos(v.price) });
  }
  return [...grupos].map(([nome, m]) => ({ nome, opcoes: [...m.values()] }));
}
function variacoesDoCatalogo(prod: any): Dados["variacoes"] {
  return (prod?.pickers || []).map((p: any) => ({
    nome: String(p.picker_name || "Opção"),
    opcoes: (p.products || []).map((o: any) => ({ valor: String(o.picker_label || o.product_id), ml_produto_id: o.product_id, atual: o.product_id === prod.id })),
  })).filter((g: any) => g.opcoes.length > 1);
}

async function lerPelaApi(itemId: string | null, produtoId: string | null, tk: string, comDescricao = true): Promise<Dados> {
  let prod: any = null, item: any = null;
  if (produtoId) { try { prod = await mlGet("/products/" + produtoId, tk); } catch (e) { if (!itemId) throw e; } }
  if (!itemId && prod?.buy_box_winner?.item_id) itemId = prod.buy_box_winner.item_id;
  if (itemId) { try { item = await mlGet("/items/" + itemId, tk); } catch (e) { if (!prod) throw e; } }
  if (item && !produtoId && item.catalog_product_id) {
    produtoId = item.catalog_product_id;
    try { prod = await mlGet("/products/" + produtoId, tk); } catch (_) { /* só complementa */ }
  }
  if (!item && !prod) throw new Falha("Não encontrei esse anúncio no Mercado Livre.", 404);

  // preço: o preço de venda atual (com promoção) e o preço "de"
  let preco = centavos(item?.price ?? prod?.buy_box_winner?.price), original = centavos(item?.original_price ?? prod?.buy_box_winner?.original_price);
  if (item) {
    try {
      const sp = await mlGet("/items/" + item.id + "/sale_price?context=channel_marketplace", tk);
      if (sp?.amount != null) { preco = centavos(sp.amount); original = centavos(sp.regular_amount) ?? original; }
    } catch (_) { /* fica o preço do anúncio */ }
  }
  if (original != null && preco != null && original <= preco) original = null;

  let descricao: string | null = null;
  if (comDescricao && item) {
    try { const d = await mlGet("/items/" + item.id + "/description", tk); descricao = (d?.plain_text || "").trim() || null; } catch (_) { /* sem descrição */ }
  }
  if (!descricao && prod?.short_description?.content) descricao = String(prod.short_description.content).trim();

  const fotos = ((item?.pictures?.length ? item.pictures : prod?.pictures) || []).map((p: any) => fotoGrande(p.secure_url || p.url)).filter(Boolean).slice(0, 12);
  let variacoes = item?.variations?.length ? variacoesDoItem(item) : [];
  if (!variacoes.length) variacoes = variacoesDoCatalogo(prod);

  return {
    ml_item_id: item?.id || itemId || null,
    ml_produto_id: produtoId,
    permalink: item?.permalink || (produtoId ? "https://www.mercadolivre.com.br/p/" + produtoId + (itemId ? "?pdp_filters=item_id:" + itemId : "") : null),
    nome: String(item?.title || prod?.name || "").trim(),
    preco_centavos: preco, preco_original_centavos: original,
    desconto_pct: preco != null && original ? Math.round((1 - preco / original) * 100) : null,
    fotos, descricao,
    atributos: juntarAtributos(prod?.attributes, item?.attributes, prod?.main_features?.map((f: any) => ({ name: "Destaque", value_name: f.text }))).slice(0, 60),
    variacoes,
    condicao: item?.condition === "new" ? "Novo" : item?.condition === "used" ? "Usado" : null,
    estoque: item?.available_quantity ?? null,
    vendidos: item?.sold_quantity ?? null,
    frete_gratis: item?.shipping?.free_shipping ?? null,
    ml_status: item?.status || prod?.status || null,
    fonte: "api",
  };
}

// ---------------- leitura pela página (plano B) ----------------
function htmlTexto(s: string) { return s.replace(/&quot;/g, '"').replace(/&#x27;|&#39;/g, "'").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">"); }
async function lerPelaPagina(link: string, itemId: string | null, produtoId: string | null): Promise<Dados> {
  const url = produtoId ? "https://www.mercadolivre.com.br/p/" + produtoId + (itemId ? "?wid=" + itemId : "") : link.split("#")[0];
  const r = await fetch(url, { headers: { Accept: "text/html", "Accept-Language": "pt-BR,pt;q=0.9" }, redirect: "follow" });
  const html = await r.text();
  if (!r.ok || /suspicious-traffic|account-verification|captcha/i.test(html.slice(0, 5000))) {
    throw new Falha("O Mercado Livre não deixou o servidor ler a página do anúncio. Cadastre as chaves do app do Mercado Livre no painel (Vitrine › Conectar Mercado Livre) para usar a API oficial.", 502);
  }
  let prod: any = null;
  for (const m of html.matchAll(/<script[^>]+application\/ld\+json[^>]*>([\s\S]*?)<\/script>/gi)) {
    try {
      const j = JSON.parse(m[1]); const lista = Array.isArray(j) ? j : (j["@graph"] || [j]);
      prod = lista.find((x: any) => /Product/i.test(String(x["@type"]))) || prod;
    } catch (_) { /* ignora */ }
  }
  const meta = (p: string) => { const m = new RegExp('<meta[^>]+(?:property|name)="' + p + '"[^>]+content="([^"]*)"', "i").exec(html); return m ? htmlTexto(m[1]) : null; };
  const nome = prod?.name || meta("og:title");
  if (!nome) throw new Falha("Não consegui ler os dados da página do anúncio.", 502);
  const oferta = Array.isArray(prod?.offers) ? prod.offers[0] : prod?.offers;
  const imgs = [].concat(prod?.image || meta("og:image") || []).map((u: any) => fotoGrande(String(u)));
  return {
    ml_item_id: itemId, ml_produto_id: produtoId, permalink: url, nome: String(nome).trim(),
    preco_centavos: centavos(oferta?.price ?? oferta?.lowPrice), preco_original_centavos: null, desconto_pct: null,
    fotos: imgs.slice(0, 12), descricao: prod?.description || meta("og:description"),
    atributos: [prod?.brand?.name && { nome: "Marca", valor: prod.brand.name }, prod?.model && { nome: "Modelo", valor: String(prod.model) }, prod?.color && { nome: "Cor", valor: prod.color }].filter(Boolean) as any,
    variacoes: [], condicao: /NewCondition/.test(String(oferta?.itemCondition || "")) ? "Novo" : null,
    estoque: null, vendidos: null, frete_gratis: null, ml_status: /InStock/.test(String(oferta?.availability || "")) ? "active" : null, fonte: "pagina",
  };
}

async function lerAnuncio(link: string, comDescricao = true): Promise<Dados> {
  const { itemId, produtoId } = codigosDoLink(link);
  if (!itemId && !produtoId) throw new Falha("Esse link não parece ser de um anúncio do Mercado Livre (não achei o código MLB...).");
  const tk = await token();
  if (tk) return await lerPelaApi(itemId, produtoId, tk, comDescricao);
  return await lerPelaPagina(link, itemId, produtoId);
}

// ---------------- gravar na tabela ----------------
const CAMPOS_ML = ["ml_item_id", "ml_produto_id", "permalink", "nome", "preco_centavos", "preco_original_centavos", "desconto_pct", "fotos", "descricao", "atributos", "variacoes", "condicao", "estoque", "vendidos", "frete_gratis", "ml_status", "fonte"] as const;
// manual = botão "Atualizar" do painel (relê também a descrição); diária = só se a descrição estiver vazia (gasta menos)
async function atualizarLinha(linha: any, manual = false) {
  try {
    const d: any = await lerAnuncio(linha.link || ("https://www.mercadolivre.com.br/p/" + linha.ml_produto_id + "?wid=" + linha.ml_item_id), manual || !linha.descricao);
    const up: Record<string, unknown> = { atualizado_ml_em: new Date().toISOString(), ultimo_erro: null };
    for (const k of CAMPOS_ML) if (d[k] != null && !(k === "descricao" && !d[k]) && !(Array.isArray(d[k]) && !d[k].length && k !== "variacoes")) up[k] = d[k];
    if (linha.travar_textos) { delete up.nome; delete up.descricao; } // o admin reescreveu nome/descrição: mantém os dele
    const r = await sb.from("vitrine_ml").update(up).eq("id", linha.id).select("*").single();
    if (r.error) throw new Falha(r.error.message, 500);
    return { ok: true, produto: r.data };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await sb.from("vitrine_ml").update({ ultimo_erro: msg.slice(0, 500) }).eq("id", linha.id);
    return { ok: false, id: linha.id, erro: msg };
  }
}

async function atualizarTodos() {
  const inicio = Date.now(), limiteMs = 110_000;
  const r = await sb.from("vitrine_ml").select("*").eq("auto_atualizar", true).order("atualizado_ml_em", { ascending: true, nullsFirst: true });
  if (r.error) throw new Falha(r.error.message, 500);
  const fila = r.data || [], res = { total: fila.length, atualizados: 0, falhas: [] as { id: number; nome: string; erro: string }[], faltaram: 0 };
  let i = 0;
  async function trabalhador() {
    while (i < fila.length) {
      if (Date.now() - inicio > limiteMs) { res.faltaram = fila.length - i; i = fila.length; return; }
      const linha = fila[i++];
      const x = await atualizarLinha(linha);
      if (x.ok) res.atualizados++; else res.falhas.push({ id: linha.id, nome: linha.nome, erro: (x as any).erro });
    }
  }
  await Promise.all([trabalhador(), trabalhador(), trabalhador()]);
  await gravarAjustes({ ultima_rodada: JSON.stringify({ em: new Date().toISOString(), ...res, falhas: res.falhas.length }) });
  return res;
}

// ---------------- quem está chamando ----------------
async function autorizado(req: Request) {
  const segredo = req.headers.get("x-cron-segredo");
  if (segredo) { const certo = await ajuste("cron_segredo"); return !!certo && segredo === certo; }
  const jwt = (req.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
  if (!jwt) return false;
  const u = await sb.auth.getUser(jwt);
  if (u.error || !u.data.user) return false;
  const p = await sb.from("perfis").select("papel").eq("id", u.data.user.id).maybeSingle();
  return p.data?.papel === "admin";
}

// ---------------- autorização do app (opcional, só se o ML pedir) ----------------
async function voltaDaAutorizacao(url: URL) {
  const pagina = (t: string) => new Response('<!doctype html><meta charset="utf-8"><title>Portal Cosmoria</title><body style="font-family:sans-serif;padding:40px;max-width:560px;margin:auto"><h1>Portal Cosmoria</h1><p>' + t + "</p></body>", { headers: { "Content-Type": "text/html; charset=utf-8" } });
  const code = url.searchParams.get("code"), state = url.searchParams.get("state");
  const esperado = await ajuste("oauth_state");
  if (!code || !state || !esperado || state !== esperado) return pagina("Link de autorização inválido ou vencido. Gere outro no painel.");
  const app = await chavesApp(); if (!app) return pagina("Cadastre o Client ID e a Secret Key no painel antes de autorizar.");
  try {
    const j = await pedirToken({ grant_type: "authorization_code", client_id: app.id, client_secret: app.segredo, code, redirect_uri: URL_FUNCAO });
    await gravarAjustes({ access_token: j.access_token, token_expira_em: String(Date.now() + (Number(j.expires_in) || 21600) * 1000), refresh_token: j.refresh_token || "", oauth_state: "" });
    return pagina("Pronto! O Mercado Livre foi conectado à vitrine. Pode fechar esta aba e voltar ao painel.");
  } catch (e) { return pagina("Não deu certo: " + (e instanceof Error ? e.message : e)); }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const url = new URL(req.url);
  if (req.method === "GET") {
    if (url.searchParams.has("code")) return await voltaDaAutorizacao(url);
    return json({ ok: true, funcao: "vitrine-ml" });
  }
  try {
    if (!(await autorizado(req))) return json({ erro: "Só administradores podem usar esta função." }, 401);
    const corpo = await req.json().catch(() => ({}));
    switch (corpo.acao) {
      case "ler": {
        const dados = await lerAnuncio(String(corpo.link || ""));
        const ja = dados.ml_item_id ? await sb.from("vitrine_ml").select("id,nome").eq("ml_item_id", dados.ml_item_id).maybeSingle() : { data: null };
        return json({ ok: true, dados, ja_cadastrado: ja.data || null });
      }
      case "atualizar": {
        const r = await sb.from("vitrine_ml").select("*").eq("id", corpo.id).maybeSingle();
        if (!r.data) throw new Falha("Produto não encontrado.", 404);
        const x = await atualizarLinha(r.data, true);
        return json(x, x.ok ? 200 : 502);
      }
      case "atualizar_todos": return json({ ok: true, ...(await atualizarTodos()) });
      case "link_autorizacao": {
        const app = await chavesApp(); if (!app) throw new Falha("Cadastre o Client ID e a Secret Key primeiro.");
        const state = crypto.randomUUID(); await gravarAjustes({ oauth_state: state });
        return json({ ok: true, url: "https://auth.mercadolivre.com.br/authorization?response_type=code&client_id=" + encodeURIComponent(app.id) + "&redirect_uri=" + encodeURIComponent(URL_FUNCAO) + "&state=" + state, redirect_uri: URL_FUNCAO });
      }
      case "testar": { const tk = await token(); return json({ ok: true, api: !!tk }); }
      default: throw new Falha("Ação desconhecida.");
    }
  } catch (e) {
    const status = e instanceof Falha ? e.status : 500;
    return json({ erro: e instanceof Error ? e.message : String(e) }, status);
  }
});
