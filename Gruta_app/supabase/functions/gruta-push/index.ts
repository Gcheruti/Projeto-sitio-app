// Gruta · push para todos os celulares (ESQUELETO, ainda desligado).
//
// Hoje os avisos do painel /adm ficam na tabela gruta.notificacoes e
// aparecem no sino do app (e como notificação do aparelho quando o app é
// aberto). Para chegar com o app FECHADO é preciso:
//   1. Criar o app Gruta no Firebase (Android + iOS) e colocar
//      google-services.json / GoogleService-Info.plist no projeto;
//   2. No iOS, subir a chave APNs no Firebase;
//   3. Adicionar firebase_messaging ao app e gravar o token de cada aparelho
//      numa tabela gruta.dispositivos;
//   4. Guardar a conta de serviço do Firebase como segredo FCM_SERVICE_ACCOUNT
//      e completar o envio abaixo (FCM HTTP v1, tópico "gruta-todos").
// Ver docs/ADMIN.md.
//
// Publicar: supabase functions deploy gruta-push
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Só admin da Gruta pode disparar.
  const auth = req.headers.get("Authorization") ?? "";
  const cliente = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: ehAdmin } = await cliente.schema("gruta").rpc("eh_admin");
  if (ehAdmin !== true) {
    return new Response(JSON.stringify({ erro: "sem permissão" }), {
      status: 403,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  if (!Deno.env.get("FCM_SERVICE_ACCOUNT")) {
    return new Response(
      JSON.stringify({ ok: false, motivo: "push ainda não configurado" }),
      { status: 501, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  // TODO: gerar o token OAuth da conta de serviço e enviar para
  // https://fcm.googleapis.com/v1/projects/<id>/messages:send
  // com { message: { topic: "gruta-todos", notification: { title, body } } }.
  return new Response(JSON.stringify({ ok: false, motivo: "a completar" }), {
    status: 501,
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
