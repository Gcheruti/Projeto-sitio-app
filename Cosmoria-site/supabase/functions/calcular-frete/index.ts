// DESATIVADO (modo vitrine, nov/2026): o site não calcula mais frete; entrega e frete são do Mercado Livre.
// O código fica guardado para poder voltar (js/config.js > modoVitrine: false e reativar o <script src="js/frete.js"> nas páginas).
// Função de frete da Cosmoria (Supabase Edge Function).
// Recebe { cep, itens: [{ variante_id, quantidade }] } e devolve as opções de entrega.
// Versão de teste: distância em linha reta x fator_rota e Correios por tabela provisória por estado.
import postgres from "npm:postgres@3.4.4";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 3 });

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function resposta(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

// Faixas de CEP por estado (Correios)
const FAIXAS: [number, number, string][] = [
  [1000, 19999, "SP"], [20000, 28999, "RJ"], [29000, 29999, "ES"], [30000, 39999, "MG"],
  [40000, 48999, "BA"], [49000, 49999, "SE"], [50000, 56999, "PE"], [57000, 57999, "AL"],
  [58000, 58999, "PB"], [59000, 59999, "RN"], [60000, 63999, "CE"], [64000, 64999, "PI"],
  [65000, 65999, "MA"], [66000, 68899, "PA"], [68900, 68999, "AP"], [69000, 69299, "AM"],
  [69300, 69399, "RR"], [69400, 69899, "AM"], [69900, 69999, "AC"], [70000, 72799, "DF"],
  [72800, 72999, "GO"], [73000, 73699, "DF"], [73700, 76799, "GO"], [76800, 76999, "RO"],
  [77000, 77999, "TO"], [78000, 78899, "MT"], [79000, 79999, "MS"], [80000, 87999, "PR"],
  [88000, 89999, "SC"], [90000, 99999, "RS"],
];
function ufDoCep(cep: string) {
  const n = Number(cep.slice(0, 5));
  return FAIXAS.find(([a, b]) => n >= a && n <= b)?.[2] ?? null;
}

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const r = (g: number) => (g * Math.PI) / 180;
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(a));
}

let rastro: string[] = []; // diagnóstico (só volta na resposta com "debug": true)
async function json(url: string) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 6000);
  const host = new URL(url).host;
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { "User-Agent": "loja-frete/1.0 (teste)", "Accept": "application/json" } });
    rastro.push(`${host} ${r.status}`);
    return r.ok ? await r.json() : null;
  } catch (e) { rastro.push(`${host} erro ${String(e).slice(0, 80)}`); return null; } finally { clearTimeout(t); }
}

// CEP -> endereço (ViaCEP/BrasilAPI) -> coordenadas (Photon, busca gratuita do OpenStreetMap, sem cadastro).
// Os serviços de CEP sozinhos costumam devolver só o centro da cidade, por isso a posição vem da rua
// (ou, se não achar, do bairro).
async function localizar(texto: string) {
  const u = new URL("https://photon.komoot.io/api/");
  u.searchParams.set("q", texto);
  u.searchParams.set("limit", "1");
  u.searchParams.set("lat", "-23.55");
  u.searchParams.set("lon", "-46.63");
  const r = await json(u.toString());
  const c = r?.features?.[0]?.geometry?.coordinates;
  return Array.isArray(c) ? { lat: Number(c[1]), lng: Number(c[0]) } : null;
}
async function coordenadas(cep: string): Promise<{ lat: number; lng: number } | null> {
  let end = await json(`https://viacep.com.br/ws/${cep}/json/`);
  if (!end || end.erro) {
    const b = await json(`https://brasilapi.com.br/api/cep/v1/${cep}`);
    end = b ? { logradouro: b.street, bairro: b.neighborhood, localidade: b.city, uf: b.state } : null;
  }
  if (!end || !end.localidade) return null;
  const rua = String(end.logradouro ?? "").trim(), bairro = String(end.bairro ?? "").trim();
  if (rua) {
    const p = await localizar(`${rua}, ${bairro ? bairro + ", " : ""}${end.localidade}, ${end.uf ?? ""}, Brasil`);
    if (p) return p;
  }
  if (bairro) return await localizar(`${bairro}, ${end.localidade}, ${end.uf ?? ""}, Brasil`);
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resposta({ erro: "Use POST." }, 405);

  rastro = [];
  let corpo: any;
  try { corpo = await req.json(); } catch { return resposta({ erro: "Corpo inválido." }, 400); }

  const cep = String(corpo?.cep ?? "").replace(/\D/g, "");
  if (cep.length !== 8) return resposta({ erro: "CEP inválido. Use 8 números." }, 400);
  const uf = ufDoCep(cep);
  if (!uf) return resposta({ erro: "CEP não encontrado." }, 400);

  const itens = Array.isArray(corpo?.itens) ? corpo.itens.slice(0, 50) : [];
  const qtdPorVariante = new Map<number, number>();
  for (const i of itens) {
    const id = Number(i?.variante_id), q = Math.floor(Number(i?.quantidade ?? i?.qtd ?? 1));
    if (Number.isInteger(id) && id > 0 && q > 0 && q <= 99) qtdPorVariante.set(id, (qtdPorVariante.get(id) ?? 0) + q);
  }
  if (!qtdPorVariante.size) return resposta({ erro: "Nenhum item informado." }, 400);

  try {
    const [cfg] = await sql`select * from "Cosmoria".frete_config where id`;
    const linhas = await sql`
      select v.id,
             coalesce(v.preco_centavos, p.preco_promocional_centavos, p.preco_centavos) as preco,
             coalesce(v.peso_gramas, p.peso_gramas) as peso
      from "Cosmoria".variantes v join "Cosmoria".produtos p on p.id = v.produto_id
      where p.ativo and v.id = any(${[...qtdPorVariante.keys()]}::bigint[])`;
    if (!linhas.length) return resposta({ erro: "Produtos não encontrados." }, 400);

    let subtotal = 0, pesoG = 0;
    for (const l of linhas) {
      const q = qtdPorVariante.get(Number(l.id)) ?? 0;
      subtotal += Number(l.preco) * q;
      pesoG += Number(l.peso) * q;
    }
    const gratis = subtotal > Number(cfg.frete_gratis_acima_centavos);
    const opcoes: any[] = [];

    // Motoboy: só Grande São Paulo (CEP 01000 a 09999). Distância guardada por 90 dias.
    const metro = Number(cep.slice(0, 5)) < 10000;
    let km: number | null = null;
    if (metro) {
      const [cache] = await sql`select lat, lng from "Cosmoria".frete_distancias
                                 where cep = ${cep} and lat is not null and atualizado_em > now() - interval '90 days'`;
      let pos = cache ? { lat: Number(cache.lat), lng: Number(cache.lng) } : await coordenadas(cep);
      if (pos) {
        km = Math.round(haversineKm(cfg.origem_lat, cfg.origem_lng, pos.lat, pos.lng) * Number(cfg.fator_rota) * 10) / 10;
        if (!cache) {
          await sql`insert into "Cosmoria".frete_distancias (cep, lat, lng, km, metodo)
                    values (${cep}, ${pos.lat}, ${pos.lng}, ${km}, 'linha_reta')
                    on conflict (cep) do update set lat = excluded.lat, lng = excluded.lng, km = excluded.km,
                    metodo = excluded.metodo, atualizado_em = now()`;
        }
      }
    }

    if (km != null && km <= Number(cfg.km_maximo)) {
      const preco = Math.round(Math.max(0, km - Number(cfg.km_gratis)) * Number(cfg.preco_km_centavos));
      opcoes.push({ modalidade: "motoboy", nome: "Motoboy", preco_centavos: gratis ? 0 : preco,
        prazo_dias: Number(cfg.motoboy_prazo_dias), distancia_km: km });
    }

    // Correios: tabela provisória por estado
    const [t] = await sql`select * from "Cosmoria".frete_tabela_estados where uf = ${uf}`;
    if (t) {
      const kgExtra = Math.max(0, Math.ceil(pesoG / 1000) - 1);
      const m = Number(cfg.manuseio_dias);
      opcoes.push({ modalidade: "pac", nome: "Correios PAC",
        preco_centavos: gratis ? 0 : t.pac_centavos + kgExtra * cfg.pac_adicional_kg_centavos, prazo_dias: t.pac_prazo_dias + m });
      opcoes.push({ modalidade: "sedex", nome: "Correios SEDEX",
        preco_centavos: gratis ? 0 : t.sedex_centavos + kgExtra * cfg.sedex_adicional_kg_centavos, prazo_dias: t.sedex_prazo_dias + m });
    }

    return resposta({ cep, uf, distancia_km: km, subtotal_centavos: subtotal, peso_gramas: pesoG,
      frete_gratis: gratis, frete_gratis_acima_centavos: Number(cfg.frete_gratis_acima_centavos), opcoes,
      ...(corpo?.debug ? { debug: rastro } : {}) });
  } catch (e) {
    console.error(e);
    return resposta({ erro: "Não foi possível calcular o frete agora." }, 500);
  }
});
