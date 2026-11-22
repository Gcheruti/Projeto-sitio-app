// Configuração da loja Portal Cosmoria.
// A chave abaixo é a chave PÚBLICA (publishable) do Supabase: pode ficar no site.
// Nunca coloque aqui a chave "service_role" ou "secret".
window.COSMORIA = {
  supabaseUrl: 'https://cucabiqhtwqlxujgflnq.supabase.co',
  supabaseKey: 'sb_publishable_qn6l-R9jyqMa1yTNZfQGLQ_iSQailRZ',
  esquema: 'Cosmoria',
  // MODO VITRINE: o site mostra os produtos do Mercado Livre (tabela vitrine_ml) e a compra acontece no ML.
  // Frete, carrinho e checkout ficam DESATIVADOS (o código continua nos arquivos e pode voltar).
  // Para voltar à loja com carrinho e o cadastro antigo de produtos, troque para false.
  modoVitrine: true,
  parcelasSemJuros: 3,      // exemplo: ajuste quando definir o meio de pagamento
  descontoPix: 0.05,        // 5% no Pix (exemplo)
  freteGratisAcima: 15000,  // em centavos: frete grátis acima de R$ 150,00
  whatsapp: '[NÚMERO]',
  email: '[E-MAIL]',
  logo: ''                  // ex.: 'img/logo.png' quando o logo estiver na pasta img/
};
