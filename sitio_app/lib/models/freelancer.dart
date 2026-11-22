import 'package:flutter/material.dart';

/// Cargos de freelancer (por enquanto 3; fácil de ampliar).
class CargoFreelancer {
  const CargoFreelancer(this.chave, this.nome, this.cor);
  final String chave;
  final String nome;
  final Color cor;
}

const List<CargoFreelancer> kCargosFreelancer = [
  CargoFreelancer('limpeza', 'Equipe de limpeza', Colors.blue),
  CargoFreelancer('garcom', 'Equipe de garçons', Colors.red),
  CargoFreelancer('auxilio', 'Auxílio geral', Colors.green),
];

CargoFreelancer? cargoPorChave(String chave) {
  for (final c in kCargosFreelancer) {
    if (c.chave == chave) return c;
  }
  return null;
}

/// Um dia agendado de um freelancer.
class DiaFreelancer {
  DiaFreelancer({
    required this.id,
    required this.usuarioId,
    required this.dia,
    required this.cargo,
    required this.valor,
    this.loginEm,
    this.logoutEm,
  });

  final String id;
  final String usuarioId;
  final DateTime dia; // só a data
  final String cargo;
  final double valor;
  final DateTime? loginEm;
  final DateTime? logoutEm;

  bool get presente => loginEm != null;
}
