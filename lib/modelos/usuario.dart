import 'package:flutter/material.dart';

/// Os 4 papéis do sistema. Cada um vê um conjunto de telas.
enum Perfil {
  cliente('Cliente / Responsável', Icons.family_restroom),
  recepcao('Recepção', Icons.support_agent),
  fono('Fonoaudiólogo(a)', Icons.medical_services_outlined),
  dono('Dono(a) da clínica', Icons.apartment);

  const Perfil(this.rotulo, this.icone);
  final String rotulo;
  final IconData icone;

  static Perfil porNome(String? nome) =>
      Perfil.values.firstWhere((p) => p.name == nome, orElse: () => cliente);
}

/// Permissões configuráveis na tela "Equipe e Permissões".
class Permissoes {
  const Permissoes({
    this.agenda = false,
    this.cadastros = false,
    this.cobranca = false,
    this.clinico = false,
    this.financeiro = false,
  });

  final bool agenda;
  final bool cadastros;
  final bool cobranca;
  final bool clinico;
  final bool financeiro;

  factory Permissoes.padrao(Perfil perfil) => switch (perfil) {
    Perfil.cliente => const Permissoes(),
    Perfil.recepcao => const Permissoes(
      agenda: true,
      cadastros: true,
      cobranca: true,
    ),
    Perfil.fono => const Permissoes(agenda: true, clinico: true),
    Perfil.dono => const Permissoes(
      agenda: true,
      cadastros: true,
      cobranca: true,
      clinico: true,
      financeiro: true,
    ),
  };

  Permissoes copyWith({
    bool? agenda,
    bool? cadastros,
    bool? cobranca,
    bool? clinico,
    bool? financeiro,
  }) => Permissoes(
    agenda: agenda ?? this.agenda,
    cadastros: cadastros ?? this.cadastros,
    cobranca: cobranca ?? this.cobranca,
    clinico: clinico ?? this.clinico,
    financeiro: financeiro ?? this.financeiro,
  );

  Map<String, dynamic> toMap() => {
    'agenda': agenda,
    'cadastros': cadastros,
    'cobranca': cobranca,
    'clinico': clinico,
    'financeiro': financeiro,
  };

  factory Permissoes.fromMap(Map<String, dynamic>? m) => Permissoes(
    agenda: m?['agenda'] == true,
    cadastros: m?['cadastros'] == true,
    cobranca: m?['cobranca'] == true,
    clinico: m?['clinico'] == true,
    financeiro: m?['financeiro'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is Permissoes &&
      other.agenda == agenda &&
      other.cadastros == cadastros &&
      other.cobranca == cobranca &&
      other.clinico == clinico &&
      other.financeiro == financeiro;

  @override
  int get hashCode =>
      Object.hash(agenda, cadastros, cobranca, clinico, financeiro);
}

/// Pessoa que acessa o app (documento em `usuarios/{uid}`).
class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.cargo = '',
    this.registro = '',
    this.especialidade = '',
    this.pacienteId,
    this.parentesco = '',
    this.permissoes = const Permissoes(),
    this.ativo = true,
    this.convidado = false,
  });

  final String id;
  final String nome;
  final String email;
  final Perfil perfil;

  /// Rótulo exibido na equipe: "Titular", "Fonoaudióloga", "Recepção / Balcão"…
  final String cargo;

  /// Registro profissional (CRFa). Sem ele não há acesso clínico (sigilo).
  final String registro;
  final String especialidade;

  /// Para clientes: qual paciente esta conta acompanha.
  final String? pacienteId;
  final String parentesco;
  final Permissoes permissoes;
  final bool ativo;
  final bool convidado;

  bool get temCrfa => registro.trim().isNotEmpty;
  bool get ehProfissionalClinico =>
      perfil == Perfil.fono || (perfil == Perfil.dono && temCrfa);

  Usuario copyWith({Permissoes? permissoes, String? nome}) => Usuario(
    id: id,
    nome: nome ?? this.nome,
    email: email,
    perfil: perfil,
    cargo: cargo,
    registro: registro,
    especialidade: especialidade,
    pacienteId: pacienteId,
    parentesco: parentesco,
    permissoes: permissoes ?? this.permissoes,
    ativo: ativo,
    convidado: convidado,
  );

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'email': email,
    'perfil': perfil.name,
    'cargo': cargo,
    'registro': registro,
    'especialidade': especialidade,
    'pacienteId': pacienteId,
    'parentesco': parentesco,
    'permissoes': permissoes.toMap(),
    'ativo': ativo,
    'convidado': convidado,
  };

  factory Usuario.fromMap(String id, Map<String, dynamic> m) => Usuario(
    id: id,
    nome: m['nome'] as String? ?? '',
    email: m['email'] as String? ?? '',
    perfil: Perfil.porNome(m['perfil'] as String?),
    cargo: m['cargo'] as String? ?? '',
    registro: m['registro'] as String? ?? '',
    especialidade: m['especialidade'] as String? ?? '',
    pacienteId: m['pacienteId'] as String?,
    parentesco: m['parentesco'] as String? ?? '',
    permissoes: Permissoes.fromMap(m['permissoes'] as Map<String, dynamic>?),
    ativo: m['ativo'] as bool? ?? true,
    convidado: m['convidado'] as bool? ?? false,
  );
}
