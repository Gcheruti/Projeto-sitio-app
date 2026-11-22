import 'freelancer.dart';

/// Uma função do app que o Adm pode ligar/desligar por perfil.
class Permissao {
  const Permissao(this.chave, this.nome, this.grupo, {this.detalhe});
  final String chave;
  final String nome;
  final String grupo;
  final String? detalhe;
}

/// Perfil de acesso (o Adm sempre tem tudo e não aparece aqui).
class PerfilAcesso {
  const PerfilAcesso(this.chave, this.nome, {this.explicacao});
  final String chave;
  final String nome;
  final String? explicacao;
}

const List<String> kGruposPermissao = [
  'Abas do aplicativo',
  'Início',
  'Agenda',
  'Comandas',
  'Pedidos',
  'Estoque',
  'Ajustes',
];

const List<Permissao> kPermissoes = [
  // Abas
  Permissao('aba_inicio', 'Aba Início (mapa e avisos)', 'Abas do aplicativo'),
  Permissao('aba_comandas', 'Aba Comandas', 'Abas do aplicativo'),
  Permissao('aba_pedidos', 'Aba Pedidos', 'Abas do aplicativo'),
  Permissao('aba_estoque', 'Aba Estoque', 'Abas do aplicativo'),
  // Início
  Permissao('inicio_agenda', 'Ícone da agenda', 'Início'),
  Permissao('inicio_notificacoes', 'Ver avisos (sino e mapa)', 'Início'),
  Permissao('notif_editar', 'Criar, editar e excluir avisos', 'Início'),
  // Agenda
  Permissao('agenda_geral', 'Ver a agenda geral', 'Agenda'),
  Permissao('agenda_bruxa', 'Ver a agenda da Casa da Bruxa', 'Agenda'),
  Permissao('agenda_editar', 'Agendar, mover e remover', 'Agenda'),
  Permissao('agenda_config', 'Configurar cores e ícones da agenda', 'Agenda'),
  // Comandas
  Permissao('comanda_criar', 'Criar comanda', 'Comandas'),
  Permissao('comanda_itens', 'Adicionar itens e vincular NFC', 'Comandas'),
  Permissao('comanda_fechar', 'Fechar comanda', 'Comandas'),
  Permissao('comanda_reabrir', 'Reabrir e resetar comanda', 'Comandas'),
  Permissao('comanda_excluir', 'Excluir comanda', 'Comandas'),
  // Pedidos
  Permissao('pedidos_status', 'Mudar a etapa do preparo', 'Pedidos'),
  // Estoque
  Permissao('estoque_cadastrar', 'Cadastrar produtos e campos avançados', 'Estoque'),
  // Ajustes
  Permissao('ajustes_reposicao', 'Reposição', 'Ajustes'),
  Permissao('ajustes_baixa', 'Baixa de estoque', 'Ajustes'),
  Permissao('ajustes_relatorios', 'Relatórios', 'Ajustes'),
  Permissao('ajustes_nfc', 'NFC', 'Ajustes'),
  Permissao('ajustes_equipe', 'Manutenção de equipe', 'Ajustes'),
  Permissao('ajustes_trocas', 'Sistema de trocas', 'Ajustes'),
  Permissao('ajustes_notificacoes', 'Enviar notificação', 'Ajustes'),
];

/// Perfis que podem ser configurados. Cada função de freelancer vira um perfil:
/// o app escolhe sozinho pelo dia (agenda de freelancers).
List<PerfilAcesso> get kPerfisAcesso => [
      const PerfilAcesso('staff', 'Staff'),
      for (final c in kCargosFreelancer)
        PerfilAcesso('freelancer_${c.chave}', 'Freelancer • ${c.nome}',
            explicacao:
                'Vale para o freelancer nos dias em que ele está agendado como "${c.nome}".'),
      const PerfilAcesso('freelancer', 'Freelancer • sem função hoje',
          explicacao:
              'Vale para o freelancer em dia SEM diária agendada (ou fora da agenda).'),
      const PerfilAcesso('cozinha', 'Cozinha',
          explicacao: 'A tela da cozinha é fixa (só pedidos em processo).'),
      const PerfilAcesso('totem', 'Totem',
          explicacao:
              'A tela do totem é fixa; por enquanto não há funções para ligar/desligar aqui.'),
    ];

/// Funções que fazem sentido para o perfil (cozinha e totem têm tela fixa).
bool permissaoAplica(String perfil, String chave) {
  if (perfil == 'cozinha') return chave == 'pedidos_status';
  if (perfil == 'totem') return false;
  return true;
}

const Set<String> _staffNao = {
  'estoque_cadastrar',
  'ajustes_reposicao',
  'ajustes_relatorios',
  'ajustes_nfc',
  'ajustes_equipe',
  'ajustes_trocas',
  'ajustes_notificacoes',
};

/// Valor usado enquanto o Adm não mudou nada (mantém o que o app já fazia).
bool permissaoPadrao(String perfil, String chave) {
  switch (perfil) {
    case 'staff':
      return !_staffNao.contains(chave);
    case 'freelancer_garcom':
      return const {
        'aba_inicio', 'aba_comandas', 'aba_pedidos', 'aba_estoque',
        'inicio_notificacoes', 'comanda_criar', 'comanda_itens',
        'comanda_fechar', 'pedidos_status',
      }.contains(chave);
    case 'freelancer_limpeza':
      return const {'aba_inicio', 'inicio_notificacoes'}.contains(chave);
    case 'freelancer_auxilio':
      return const {
        'aba_inicio', 'aba_comandas', 'aba_estoque', 'inicio_notificacoes',
        'comanda_itens',
      }.contains(chave);
    case 'cozinha':
      return chave == 'pedidos_status';
    case 'totem':
      return false;
    default: // 'freelancer' e funções novas ainda sem regra
      return const {'aba_inicio', 'inicio_notificacoes'}.contains(chave);
  }
}
