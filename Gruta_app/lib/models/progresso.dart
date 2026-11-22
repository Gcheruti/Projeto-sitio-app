import 'plano.dart';

/// Aula concluída por quem está usando o app.
class AulaConcluida {
  const AulaConcluida(this.aulaId, this.em);
  final String aulaId;
  final DateTime em;

  Map<String, dynamic> toJson() =>
      {'aula_id': aulaId, 'em': em.toIso8601String()};

  factory AulaConcluida.fromJson(Map<String, dynamic> m) => AulaConcluida(
      m['aula_id'].toString(), DateTime.parse(m['em'] as String).toLocal());
}

/// Anotação no Grimório (o caderno pessoal de cada pessoa).
class NotaGrimorio {
  const NotaGrimorio({
    required this.id,
    required this.texto,
    required this.criadaEm,
    this.aulaId,
    this.aulaTitulo,
  });

  final String id;
  final String texto;
  final DateTime criadaEm;
  final String? aulaId;
  final String? aulaTitulo;

  Map<String, dynamic> toJson() => {
        'id': id,
        'texto': texto,
        'criada_em': criadaEm.toIso8601String(),
        'aula_id': aulaId,
        'aula_titulo': aulaTitulo,
      };

  factory NotaGrimorio.fromJson(Map<String, dynamic> m) => NotaGrimorio(
        id: m['id'].toString(),
        texto: m['texto'] as String,
        criadaEm: DateTime.parse(m['criada_em'] as String).toLocal(),
        aulaId: m['aula_id']?.toString(),
        aulaTitulo: m['aula_titulo'] as String?,
      );
}

/// Perfil: dados do cadastro e preferências.
class Perfil {
  const Perfil({
    this.nome = '',
    this.nomeCompleto = '',
    this.nascimento,
    this.login = '',
    this.telefone = '',
    this.email = '',
    this.plano = Plano.visitante,
    this.admin = false,
    this.metaMinutos = 5,
    this.lembreteHora = 20,
    this.lembreteMinuto = 0,
    this.lembreteAtivo = true,
    this.trilhasInteresse = const [],
  });

  /// Nome de exibição (como o app chama a pessoa).
  final String nome;
  final String nomeCompleto;
  final DateTime? nascimento;

  /// Usuário de acesso (o "login").
  final String login;

  /// Contato (não é usado para entrar: o login é o usuário).
  final String telefone;
  final String email;
  final Plano plano;

  /// Só o banco define (perfis.papel = 'admin').
  final bool admin;

  final int metaMinutos;
  final int lembreteHora;
  final int lembreteMinuto;
  final bool lembreteAtivo;
  final List<String> trilhasInteresse; // slugs

  bool get assinante => plano != Plano.visitante;

  Perfil copyWith({
    String? nome,
    String? nomeCompleto,
    DateTime? nascimento,
    String? login,
    String? telefone,
    String? email,
    Plano? plano,
    bool? admin,
    int? metaMinutos,
    int? lembreteHora,
    int? lembreteMinuto,
    bool? lembreteAtivo,
    List<String>? trilhasInteresse,
  }) =>
      Perfil(
        nome: nome ?? this.nome,
        nomeCompleto: nomeCompleto ?? this.nomeCompleto,
        nascimento: nascimento ?? this.nascimento,
        login: login ?? this.login,
        telefone: telefone ?? this.telefone,
        email: email ?? this.email,
        plano: plano ?? this.plano,
        admin: admin ?? this.admin,
        metaMinutos: metaMinutos ?? this.metaMinutos,
        lembreteHora: lembreteHora ?? this.lembreteHora,
        lembreteMinuto: lembreteMinuto ?? this.lembreteMinuto,
        lembreteAtivo: lembreteAtivo ?? this.lembreteAtivo,
        trilhasInteresse: trilhasInteresse ?? this.trilhasInteresse,
      );

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'nome_completo': nomeCompleto,
        'nascimento': nascimento?.toIso8601String().substring(0, 10),
        'login': login,
        'telefone': telefone,
        'email': email,
        'plano': plano.name,
        'papel': admin ? 'admin' : 'aluno',
        'meta_minutos': metaMinutos,
        'lembrete_hora': lembreteHora,
        'lembrete_minuto': lembreteMinuto,
        'lembrete_ativo': lembreteAtivo,
        'trilhas_interesse': trilhasInteresse,
      };

  factory Perfil.fromJson(Map<String, dynamic> m) => Perfil(
        nome: (m['nome'] ?? '') as String,
        nomeCompleto: (m['nome_completo'] ?? '') as String,
        nascimento: DateTime.tryParse((m['nascimento'] ?? '') as String),
        login: (m['login'] ?? '') as String,
        telefone: (m['telefone'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        plano: Plano.porNome(m['plano'] as String?),
        admin: m['papel'] == 'admin',
        metaMinutos: (m['meta_minutos'] ?? 5) as int,
        lembreteHora: (m['lembrete_hora'] ?? 20) as int,
        lembreteMinuto: (m['lembrete_minuto'] ?? 0) as int,
        lembreteAtivo: (m['lembrete_ativo'] ?? true) as bool,
        trilhasInteresse:
            ((m['trilhas_interesse'] ?? const []) as List).cast<String>(),
      );
}

/// Aviso enviado pela equipe (painel /adm) para todo mundo.
class Notificacao {
  const Notificacao({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.criadaEm,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String icone; // chave em kIconesAviso
  final DateTime criadaEm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descricao': descricao,
        'icone': icone,
        'criada_em': criadaEm.toUtc().toIso8601String(),
      };

  factory Notificacao.fromJson(Map<String, dynamic> m) => Notificacao(
        id: m['id'].toString(),
        titulo: m['titulo'] as String,
        descricao: (m['descricao'] ?? '') as String,
        icone: (m['icone'] ?? 'vela') as String,
        criadaEm: DateTime.parse(m['criada_em'] as String).toLocal(),
      );
}
