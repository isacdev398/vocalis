import 'conversao.dart';

/// Paciente em acompanhamento na clínica (`pacientes/{id}`).
class Paciente {
  const Paciente({
    required this.id,
    required this.nome,
    required this.dataNascimento,
    this.responsavelNome = '',
    this.parentesco = '',
    this.telefone = '',
    this.convenio = 'Particular',
    this.area = 'Linguagem',
    this.hipotese = '',
    this.foco = '',
    this.profissionalId = '',
    this.profissionalNome = '',
    this.estrelas = 0,
  });

  final String id;
  final String nome;
  final DateTime dataNascimento;
  final String responsavelNome;
  final String parentesco;
  final String telefone;
  final String convenio;

  /// Área da fonoaudiologia (Linguagem, Voz, Audiologia…).
  final String area;

  /// Hipótese diagnóstica / foco terapêutico.
  final String hipotese;

  /// Etiqueta curta exibida no atendimento (ex.: "Fricativas").
  final String foco;
  final String profissionalId;
  final String profissionalNome;

  /// Gamificação dos exercícios em casa.
  final int estrelas;

  String get primeiroNome => nome.split(' ').first;

  Map<String, dynamic> toMap() => {
    'nome': nome,
    'dataNascimento': gravarData(dataNascimento),
    'responsavelNome': responsavelNome,
    'parentesco': parentesco,
    'telefone': telefone,
    'convenio': convenio,
    'area': area,
    'hipotese': hipotese,
    'foco': foco,
    'profissionalId': profissionalId,
    'profissionalNome': profissionalNome,
    'estrelas': estrelas,
  };

  factory Paciente.fromMap(String id, Map<String, dynamic> m) => Paciente(
    id: id,
    nome: m['nome'] as String? ?? '',
    dataNascimento: lerData(m['dataNascimento']),
    responsavelNome: m['responsavelNome'] as String? ?? '',
    parentesco: m['parentesco'] as String? ?? '',
    telefone: m['telefone'] as String? ?? '',
    convenio: m['convenio'] as String? ?? 'Particular',
    area: m['area'] as String? ?? 'Linguagem',
    hipotese: m['hipotese'] as String? ?? '',
    foco: m['foco'] as String? ?? '',
    profissionalId: m['profissionalId'] as String? ?? '',
    profissionalNome: m['profissionalNome'] as String? ?? '',
    estrelas: (m['estrelas'] as num?)?.toInt() ?? 0,
  );
}
