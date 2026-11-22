// Portal Cosmoria · envia ao designer cada arte nova do editor de personalizados.
// Chamada pelo gatilho "Cosmoria".avisar_designer (cabeçalho x-webhook-secret), com { id }.
// Bot próprio da Cosmoria: segredo COSMORIA_TELEGRAM_BOT_TOKEN (se faltar, usa o TELEGRAM_BOT_TOKEN que já existe).
// Conversa do Telegram: tabela "Cosmoria".ajustes_designer (telegram_chat_id) > COSMORIA_TELEGRAM_CHAT_ID >
// a primeira conversa que mandou /start para o bot (fica guardada) > TELEGRAM_CHAT_ID.
// E-mail (Resend): ajustes_designer.email_destino > COSMORIA_EMAIL_DESTINO > EMAIL_DESTINO.
// Link da visualização 3D: ajustes_designer.site_url ou o endereço do site de onde a arte foi enviada.
// Também usa WEBHOOK_SECRET, RESEND_API_KEY e COSMORIA_EMAIL_REMETENTE.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { zipSync, strToU8 } from "npm:fflate@0.8.2";

const env = (k: string, padrao = "") => (Deno.env.get(k) ?? padrao).trim();
const BOT_PROPRIO = !!env("COSMORIA_TELEGRAM_BOT_TOKEN");
const TOKEN = env("COSMORIA_TELEGRAM_BOT_TOKEN") || env("TELEGRAM_BOT_TOKEN");
let CHAT_ID = "";
const WEBHOOK_SECRET = env("WEBHOOK_SECRET");
const RESEND_API_KEY = env("RESEND_API_KEY");
let EMAIL_DESTINO = "";
const EMAIL_REMETENTE = env("COSMORIA_EMAIL_REMETENTE") || "Portal Cosmoria <onboarding@resend.dev>";

const sb = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), { db: { schema: "Cosmoria" }, auth: { persistSession: false } });

const esc = (s: unknown) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]!));
const reais = (c: number) => (Number(c || 0) / 100).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const cm = (n: number) => String(n).replace(".", ",");

type Arquivo = { nome: string; tipo: string; base64: string; foto?: boolean };
function deDataUrl(nome: string, dataUrl: string | null, foto = false): Arquivo | null {
  if (!dataUrl) return null;
  const m = /^data:([^;]+);base64,(.*)$/s.exec(dataUrl);
  if (!m) return null;
  const ext = m[1].includes("png") ? "png" : m[1].includes("jpeg") || m[1].includes("jpg") ? "jpg" : (m[1].split("/")[1] || "bin");
  return { nome: /\.[a-z0-9]+$/i.test(nome) ? nome : `${nome}.${ext}`, tipo: m[1], base64: m[2], foto };
}
function b64(u: Uint8Array) { let s = ""; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode(...u.subarray(i, i + 0x8000)); return btoa(s); }
const blob = (a: Arquivo) => new Blob([Uint8Array.from(atob(a.base64), (c) => c.charCodeAt(0))], { type: a.tipo });
const seguro = (s: string) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^\w.\-]+/g, "_").slice(0, 80);

async function tg(metodo: string, corpo: FormData | Record<string, unknown>) {
  const ehForm = corpo instanceof FormData;
  const r = await fetch(`https://api.telegram.org/bot${TOKEN}/${metodo}`, {
    method: "POST", body: ehForm ? corpo : JSON.stringify(corpo),
    headers: ehForm ? undefined : { "Content-Type": "application/json" }, signal: AbortSignal.timeout(60000),
  });
  const j = await r.json().catch(() => ({}));
  if (!j.ok) console.log("telegram", metodo, r.status, j.description ?? "");
  return { metodo, ok: !!j.ok, erro: j.ok ? undefined : j.description };
}

async function ajustes(): Promise<Record<string, string>> {
  const { data, error } = await sb.from("ajustes_designer").select("chave, valor");
  if (error) { console.log("ajustes", error.message); return {}; }
  return Object.fromEntries((data ?? []).map((r: any) => [r.chave, String(r.valor ?? "").trim()]));
}
async function descobrirConversa(): Promise<string> { // quem mandou /start para o bot
  try {
    const r = await fetch(`https://api.telegram.org/bot${TOKEN}/getUpdates?allowed_updates=%5B%22message%22%5D`, { signal: AbortSignal.timeout(15000) });
    const j = await r.json();
    const ups = (j.result ?? []).filter((u: any) => u.message?.chat?.id).reverse();
    const id = ups.length ? String(ups[0].message.chat.id) : "";
    if (id) await sb.from("ajustes_designer").upsert({ chave: "telegram_chat_id", valor: id });
    return id;
  } catch (e) { console.log("getUpdates", String(e)); return ""; }
}
function zipar(arquivos: Arquivo[], resumo: string) {
  const f: Record<string, Uint8Array> = { "0-resumo.txt": strToU8(resumo) };
  for (const a of arquivos) f[a.nome] = Uint8Array.from(atob(a.base64), (c) => c.charCodeAt(0));
  return zipSync(f, { level: 0 }); // imagens já são comprimidas
}
const texto = (html: string) => html.replace(/<[^>]+>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&amp;/g, "&");

async function processar(id: string) {
  const aj = await ajustes();
  EMAIL_DESTINO = aj.email_destino || env("COSMORIA_EMAIL_DESTINO") || env("EMAIL_DESTINO", "coelhocheruti@gmail.com");
  CHAT_ID = aj.telegram_chat_id || env("COSMORIA_TELEGRAM_CHAT_ID") || (BOT_PROPRIO ? await descobrirConversa() : "") || env("TELEGRAM_CHAT_ID", "2038907619");
  const { data: p, error } = await sb.from("personalizacoes").select("*").eq("id", id).maybeSingle();
  if (error || !p) throw new Error("arte não encontrada: " + (error?.message ?? id));
  if (p.notificado_em) return { pulado: "já notificada" };

  const elementos: any[] = p.elementos ?? [];
  const codigo = String(p.id).slice(0, 8).toUpperCase();
  const nomePeca = String(p.dados?.nome_peca ?? "").trim();
  const titulo = nomePeca ? `“${nomePeca}” (#${codigo})` : `#${codigo}`;
  const rotulos: string[] = (Array.isArray(p.orcamento) ? p.orcamento : []).map((i: any) => i?.rotulo_lado).filter(Boolean);
  const lados = rotulos.length ? rotulos.map((r: string) => r.toLowerCase()) : (p.lados_usados ?? []).map((l: string) => (l === "frente" ? "frente" : "verso"));

  // ---------- arquivos, separados por tipo ----------
  const previas = [deDataUrl(`1-previa-frente-${codigo}`, p.previa_frente, true), deDataUrl(`1-previa-verso-${codigo}`, p.previa_verso, true)].filter(Boolean) as Arquivo[];
  const artes = [deDataUrl(`2-arte-impressao-frente-${codigo}`, p.arte_frente), deDataUrl(`2-arte-impressao-verso-${codigo}`, p.arte_verso)].filter(Boolean) as Arquivo[];
  const originais = ((p.imagens_enviadas ?? []) as any[]).map((im, i) => deDataUrl(`3-imagem-cliente-${i + 1}-${seguro(im.nome || "imagem")}`, im.dataUrl)).filter(Boolean) as Arquivo[];

  // ---------- link da visualização 3D ----------
  const base = (aj.site_url || String(p.dados?.site || "")).trim();
  const link = /^https?:\/\//.test(base) && p.chave_ver ? `${base.replace(/\/?$/, "/")}ver-arte.html?id=${p.id}&k=${p.chave_ver}` : "";

  // ---------- textos do resumo ----------
  const textos = elementos.filter((e) => e.tipo === "Texto");
  const outros = elementos.filter((e) => e.tipo !== "Texto");
  const linhaEl = (e: any) => `${e.numero}. ${e.tipo} (${e.lado}${e.camada ? `, camada ${e.camada}` : ""}) ${cm(e.largura_cm)} × ${cm(e.altura_cm)} cm`;
  const fontes = [...new Set(textos.map((t) => t.fonte))];
  const orc: any[] = Array.isArray(p.orcamento) ? p.orcamento : [];
  const medida = (o: any) => o.medicao === "area_util"
    ? `${o.area_cm2} cm² de área útil${o.blocos > 1 ? ` em ${o.blocos} áreas separadas` : ""} (arte toda: ${cm(o.largura_cm)} × ${cm(o.altura_cm)} cm)`
    : `${cm(o.largura_cm)} × ${cm(o.altura_cm)} cm = ${o.area_cm2} cm²`;
  const linhaOrc = (o: any) => `Estampa ${o.rotulo_lado}: ${medida(o)} → ${reais(o.centavos)}${o.minimo_aplicado ? " (mínimo)" : ""}`;

  const tgTexto = [
    `🎨 <b>Nova arte personalizada ${esc(titulo)}</b>`,
    ``,
    `<b>Cliente:</b> ${esc(p.cliente_nome)}`,
    `<b>Contato:</b> ${esc(p.cliente_contato)}`,
    `<b>Produto:</b> ${esc(p.produto_nome)} · ${esc(p.variante_nome)} · ${p.quantidade} un.`,
    `<b>Lados com arte:</b> ${esc(lados.join(" e "))}`,
    `<b>Pré-valor:</b> ${reais(p.preco_total_centavos)} (base ${reais(p.preco_base_centavos)} + personalização ${reais(p.preco_adicional_centavos)}, por unidade)`,
    ...orc.map((o) => "   " + esc(linhaOrc(o))),
    p.observacoes ? `<b>Observações:</b> ${esc(p.observacoes)}` : "",
    ``,
    textos.length ? `✍️ <b>Textos</b>` : "",
    ...textos.map((t) => `${t.numero}. “${esc(t.texto)}”\n   Fonte: ${esc(t.fonte)}${t.negrito ? " negrito" : ""}${t.italico ? " itálico" : ""} · cor ${esc(t.cor)} · ${cm(t.largura_cm)} × ${cm(t.altura_cm)} cm · ${esc(t.lado)}${t.contorno ? ` · contorno ${esc(t.contorno)}` : ""}`),
    outros.length ? `\n🧩 <b>Outros elementos</b>` : "",
    ...outros.map((e) => esc(linhaEl(e)) + (e.arquivo ? ` · arquivo: ${esc(e.arquivo)}` : "") + (e.emoji ? ` ${e.emoji}` : "") + (e.forma ? ` · ${esc(e.forma)} ${esc(e.cor)}` : "")),
    ``,
    link ? `🧊 <b>Ver em 3D, do jeito que o cliente montou:</b>\n${esc(link)}` : "",
    ``,
    `📦 A seguir: as prévias e o pacote .zip com ${artes.length} arte(s) para impressão (PNG transparente), ${originais.length} imagem(ns) original(is) do cliente e o resumo.`,
  ].filter((l) => l !== "").join("\n").slice(0, 4000);

  const res: Record<string, unknown> = { chat: CHAT_ID, link: link || null };
  const resumo = texto(tgTexto) + (link ? "" : "\n");
  const pacote = zipar([...previas, ...artes, ...originais], resumo), nomeZip = `arte-${codigo}-${seguro(nomePeca || String(p.cliente_nome || "cliente"))}.zip`;

  // ---------- Telegram ----------
  if (TOKEN) {
    const r: unknown[] = [];
    r.push(await tg("sendMessage", { chat_id: CHAT_ID, text: tgTexto, parse_mode: "HTML" }));
    if (previas.length) {
      const f = new FormData();
      f.append("chat_id", CHAT_ID);
      f.append("media", JSON.stringify(previas.map((a, i) => ({ type: "photo", media: `attach://f${i}`, caption: i === 0 ? `Prévia ${titulo}` : undefined }))));
      previas.forEach((a, i) => f.append(`f${i}`, blob(a), a.nome));
      r.push(await tg(previas.length > 1 ? "sendMediaGroup" : "sendPhoto", previas.length > 1 ? f : (() => { const g = new FormData(); g.append("chat_id", CHAT_ID); g.append("photo", blob(previas[0]), previas[0].nome); g.append("caption", `Prévia do produto #${codigo}`); return g; })()));
    }
    const f = new FormData();
    f.append("chat_id", CHAT_ID);
    f.append("document", new Blob([pacote], { type: "application/zip" }), nomeZip);
    f.append("caption", `Pacote da arte ${titulo}: prévias, arte para impressão, imagens do cliente e resumo`);
    r.push(await tg("sendDocument", f));
    res.telegram = r;
  } else res.telegram = "sem TELEGRAM_BOT_TOKEN";

  // ---------- E-mail (Resend) ----------
  if (RESEND_API_KEY) {
    const td = 'style="padding:6px 10px;border-bottom:1px solid #e3e0d6;vertical-align:top"';
    const html = `<div style="font-family:Arial,sans-serif;color:#22302A;max-width:720px">
<h2 style="font-family:Georgia,serif;color:#142219">🎨 Nova arte personalizada ${esc(titulo)}</h2>
<h3>Cliente</h3><table cellspacing="0">
<tr><td ${td}><b>Nome</b></td><td ${td}>${esc(p.cliente_nome)}</td></tr>
<tr><td ${td}><b>Contato</b></td><td ${td}>${esc(p.cliente_contato)}</td></tr>
${p.observacoes ? `<tr><td ${td}><b>Observações</b></td><td ${td}>${esc(p.observacoes).replace(/\n/g, "<br>")}</td></tr>` : ""}</table>
<h3>Produto</h3><table cellspacing="0">
<tr><td ${td}><b>Produto</b></td><td ${td}>${esc(p.produto_nome)}</td></tr>
<tr><td ${td}><b>Cor / tamanho</b></td><td ${td}>${esc(p.variante_nome)}</td></tr>
<tr><td ${td}><b>Quantidade</b></td><td ${td}>${p.quantidade}</td></tr>
<tr><td ${td}><b>Lados com arte</b></td><td ${td}>${esc(lados.join(" e "))}</td></tr></table>
<h3>Pré-valor</h3><table cellspacing="0">
<tr><td ${td}>Produto (${esc(p.variante_nome)})</td><td ${td} align="right">${reais(p.preco_base_centavos)}</td></tr>
${orc.map((o: any) => `<tr><td ${td}>Estampa ${esc(o.rotulo_lado)}: ${esc(medida(o))} <small>(${o.area_cm2} cm² × ${reais(o.centavos_por_cm2)} por cm²${o.minimo_aplicado ? ", valor mínimo" : ""})</small></td><td ${td} align="right">${reais(o.centavos)}</td></tr>`).join("")}
<tr><td ${td}><b>Total (${p.quantidade} un.)</b></td><td ${td} align="right"><b>${reais(p.preco_total_centavos)}</b></td></tr></table>
${textos.length ? `<h3>Textos e fontes</h3><table cellspacing="0"><tr><td ${td}><b>#</b></td><td ${td}><b>Texto</b></td><td ${td}><b>Fonte</b></td><td ${td}><b>Cor</b></td><td ${td}><b>Tamanho</b></td><td ${td}><b>Lado</b></td></tr>
${textos.map((t) => `<tr><td ${td}>${t.numero}</td><td ${td}>${esc(t.texto).replace(/\n/g, "<br>")}</td><td ${td}>${esc(t.fonte)}${t.negrito ? " (negrito)" : ""}${t.italico ? " (itálico)" : ""}<br><small>alinhamento: ${esc(t.alinhamento)}${t.contorno ? `<br>contorno: ${esc(t.contorno)}` : ""}</small></td><td ${td}><span style="display:inline-block;width:14px;height:14px;border:1px solid #999;background:${esc(t.cor)}"></span> ${esc(t.cor)}</td><td ${td}>${cm(t.largura_cm)} × ${cm(t.altura_cm)} cm</td><td ${td}>${esc(t.lado)}</td></tr>`).join("")}</table>
<p style="font-size:13px">Fontes usadas (Google Fonts): ${fontes.map((f) => `<a href="https://fonts.google.com/specimen/${encodeURIComponent(String(f)).replace(/%20/g, "+")}">${esc(f)}</a>`).join(", ")}</p>` : ""}
${outros.length ? `<h3>Imagens, emojis e formas</h3><table cellspacing="0"><tr><td ${td}><b>#</b></td><td ${td}><b>Tipo</b></td><td ${td}><b>Detalhe</b></td><td ${td}><b>Tamanho</b></td><td ${td}><b>Posição (centro)</b></td><td ${td}><b>Lado</b></td></tr>
${outros.map((e) => `<tr><td ${td}>${e.numero}</td><td ${td}>${esc(e.tipo)}</td><td ${td}>${esc(e.arquivo || e.emoji || [e.forma, e.cor].filter(Boolean).join(" "))}${e.rotacao_graus ? `<br><small>girado ${e.rotacao_graus}°</small>` : ""}${e.espelhado ? "<br><small>espelhado</small>" : ""}</td><td ${td}>${cm(e.largura_cm)} × ${cm(e.altura_cm)} cm</td><td ${td}>${cm(e.centro_x_cm)} cm da esquerda, ${cm(e.centro_y_cm)} cm do topo</td><td ${td}>${esc(e.lado)}</td></tr>`).join("")}</table>` : ""}
${link ? `<p style="margin:18px 0"><a href="${esc(link)}" style="background:#C9A45C;color:#142219;padding:12px 20px;border-radius:999px;text-decoration:none;font-weight:bold">🧊 Ver a peça em 3D</a></p>` : ""}
<h3>Arquivos anexos</h3><p>Tudo junto no <b>${esc(nomeZip)}</b> (com o resumo em texto). As prévias também vão soltas para ver rápido.</p><ul>
<li><b>1-previa-…</b>: foto do produto com a arte (para conferir a aparência)</li>
<li><b>2-arte-impressao-…</b>: PNG transparente só da área de impressão, em alta resolução</li>
<li><b>3-imagem-cliente-…</b>: imagens originais que o cliente enviou</li></ul>
<p style="color:#888;font-size:12px">Aviso automático do Portal Cosmoria · arte ${esc(p.id)}</p></div>`;
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: EMAIL_REMETENTE, to: [EMAIL_DESTINO],
        subject: `Arte personalizada ${titulo}: ${p.produto_nome} (${p.variante_nome}) · ${p.cliente_nome}`,
        html, attachments: [...previas.map((a) => ({ filename: a.nome, content: a.base64 })), { filename: nomeZip, content: b64(pacote) }],
      }),
      signal: AbortSignal.timeout(60000),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) console.log("email", r.status, JSON.stringify(j).slice(0, 300));
    res.email = { ok: r.ok, status: r.status, ...j };
  } else res.email = "sem RESEND_API_KEY";

  await sb.from("personalizacoes").update({ notificado_em: new Date().toISOString(), notificacao: res }).eq("id", id);
  return res;
}

Deno.serve(async (req) => {
  if (!WEBHOOK_SECRET || req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) return new Response("unauthorized", { status: 401 });
  const { id } = await req.json().catch(() => ({}));
  if (!id) return new Response("faltou id", { status: 400 });
  const trabalho = processar(String(id)).catch((e) => console.error("erro", String(e)));
  // responde logo e continua enviando os arquivos em segundo plano
  // deno-lint-ignore no-explicit-any
  const rt = (globalThis as any).EdgeRuntime;
  if (rt?.waitUntil) { rt.waitUntil(trabalho); return Response.json({ recebido: id }, { status: 202 }); }
  return Response.json(await trabalho);
});
