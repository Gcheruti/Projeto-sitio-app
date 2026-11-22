// Gruta · cadastro por USUÁRIO e senha.
//
// Por que uma função? O projeto Supabase é compartilhado com outros apps
// que exigem confirmação por e-mail. As contas da Gruta não têm e-mail: o
// usuário vira um e-mail interno (<usuario>@usuarios.gruta.app) e a conta
// nasce já confirmada, criada aqui com a chave de serviço (que nunca vai
// para o app).
//
// Publicar (sem exigir login, porque quem chama ainda não tem conta):
//   supabase functions deploy gruta-cadastro --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const DOMINIO = "usuarios.gruta.app";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function resposta(corpo: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return resposta({ erro: "Use POST." }, 405);

  let d: Record<string, string>;
  try {
    d = await req.json();
  } catch {
    return resposta({ erro: "Dados inválidos." }, 400);
  }

  const login = String(d.login ?? "").trim().toLowerCase();
  const senha = String(d.senha ?? "");
  const nomeCompleto = String(d.nome_completo ?? "").trim().slice(0, 160);
  const nome = String(d.nome ?? nomeCompleto.split(/\s+/)[0] ?? "").slice(0, 80);
  const nascimento = String(d.nascimento ?? "");
  const planoPedido = String(d.plano ?? "visitante");

  if (!/^[a-z0-9._]{3,20}$/.test(login)) {
    return resposta({ erro: "Usuário inválido: use 3 a 20 letras, números, ponto ou _." }, 400);
  }
  if (senha.length < 6) {
    return resposta({ erro: "A senha precisa ter 6 caracteres ou mais." }, 400);
  }
  if (nomeCompleto.split(/\s+/).length < 2) {
    return resposta({ erro: "Escreva seu nome completo." }, 400);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(nascimento) || isNaN(Date.parse(nascimento))) {
    return resposta({ erro: "Data de nascimento inválida." }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const gruta = admin.schema("gruta");

  const { data: existe } = await gruta.from("perfis").select("id")
    .ilike("login", login).maybeSingle();
  if (existe) return resposta({ erro: "Esse usuário já existe. Escolha outro." }, 409);

  // Plano pago só sem pagamento enquanto o modo de teste estiver ligado.
  const { data: cfg } = await gruta.from("config").select("valor")
    .eq("chave", "planos_teste").maybeSingle();
  const teste = cfg?.valor === true;
  const plano = teste && planoPedido === "aprendiz" ? "aprendiz" : "visitante";

  const { data: criado, error: erroAuth } = await admin.auth.admin.createUser({
    email: `${login}@${DOMINIO}`,
    password: senha,
    email_confirm: true,
    user_metadata: { nome, app: "gruta" },
    app_metadata: { app: "gruta" },
  });
  if (erroAuth || !criado.user) {
    const msg = erroAuth?.message ?? "";
    if (/already|registered|exists/i.test(msg)) {
      return resposta({ erro: "Esse usuário já existe. Escolha outro." }, 409);
    }
    return resposta({ erro: "Não foi possível criar a conta agora." }, 500);
  }

  const { error: erroPerfil } = await gruta.from("perfis").insert({
    id: criado.user.id,
    login,
    nome,
    nome_completo: nomeCompleto,
    nascimento,
    plano,
  });
  if (erroPerfil) {
    // Desfaz a conta para não sobrar usuário sem perfil.
    await admin.auth.admin.deleteUser(criado.user.id);
    const dup = erroPerfil.code === "23505";
    return resposta({
      erro: dup ? "Esse usuário já existe. Escolha outro." : "Não foi possível criar a conta agora.",
    }, dup ? 409 : 500);
  }

  return resposta({ ok: true, plano });
});
