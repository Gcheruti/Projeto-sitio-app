/// Conta de acesso ao app da equipe.
class Usuario {
  Usuario({
    required this.id,
    required this.nome,
    required this.login,
    required this.papel,
    this.ativo = true,
    this.icone,
  });

  final String id;
  final String nome;
  final String login;

  /// 'adm' | 'staff' | 'freelancer' | 'totem' | 'cozinha'
  final String papel;
  final bool ativo;

  /// Só freelancer: chave do ícone na agenda (ver icones_freelancer.dart).
  final String? icone;

  bool get isAdm => papel == 'adm';
  bool get isFreelancer => papel == 'freelancer';
  bool get isTotem => papel == 'totem';
  bool get isCozinha => papel == 'cozinha';
  String get papelTexto => isAdm
      ? 'Adm'
      : (isFreelancer ? 'Freelancer' : (isTotem ? 'Totem' : (isCozinha ? 'Cozinha' : 'Staff')));

  factory Usuario.fromMap(Map<String, dynamic> m) => Usuario(
        id: m['id'].toString(),
        nome: (m['nome'] ?? '').toString(),
        login: (m['login'] ?? '').toString(),
        papel: const ['adm', 'freelancer', 'totem', 'cozinha'].contains('${m['papel']}')
            ? '${m['papel']}'
            : 'staff',
        ativo: m['ativo'] != false,
        icone: m['icone'] as String?,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'nome': nome, 'login': login, 'papel': papel, 'ativo': ativo, 'icone': icone};
}
