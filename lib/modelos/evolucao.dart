import 'conversao.dart';

/// Registro clínico de uma sessão no formato SOAP (`evolucoes/{id}`).
/// O id é o mesmo do agendamento: uma evolução por sessão.
class Evolucao {
  const Evolucao({
    required this.id,
    required this.pacienteId,
    required this.profissionalId,
    required this.profissionalNome,
    required this.data,
    this.subjetivo = '',
    this.objetivo = '',
    this.avaliacao = '',
    this.plano = '',
    this.acolhimento = '',
    this.acertos = 0,
    this.tentativas = 0,
    this.finalizada = false,
    this.sessaoNumero = 0,
  });

  final String id;
  final String pacienteId;
  final String profissionalId;
  final String profissionalNome;
  final DateTime data;

  /// S — relato do paciente/família.
  final String subjetivo;

  /// O — o que foi medido/testado.
  final String objetivo;

  /// A — parecer fonoaudiológico.
  final String avaliacao;

  /// P — plano de conduta / próximos passos.
  final String plano;
  final String acolhimento;

  /// Índice de precisão articulatória: acertos / tentativas.
  final int acertos;
  final int tentativas;
  final bool finalizada;
  final int sessaoNumero;

  double get precisao => tentativas == 0 ? 0 : acertos / tentativas;
  int get precisaoPercentual => (precisao * 100).round();

  bool get vazia =>
      subjetivo.trim().isEmpty &&
      objetivo.trim().isEmpty &&
      avaliacao.trim().isEmpty &&
      plano.trim().isEmpty;

  Evolucao copyWith({
    String? subjetivo,
    String? objetivo,
    String? avaliacao,
    String? plano,
    String? acolhimento,
    int? acertos,
    int? tentativas,
    bool? finalizada,
  }) => Evolucao(
    id: id,
    pacienteId: pacienteId,
    profissionalId: profissionalId,
    profissionalNome: profissionalNome,
    data: data,
    subjetivo: subjetivo ?? this.subjetivo,
    objetivo: objetivo ?? this.objetivo,
    avaliacao: avaliacao ?? this.avaliacao,
    plano: plano ?? this.plano,
    acolhimento: acolhimento ?? this.acolhimento,
    acertos: acertos ?? this.acertos,
    tentativas: tentativas ?? this.tentativas,
    finalizada: finalizada ?? this.finalizada,
    sessaoNumero: sessaoNumero,
  );

  Map<String, dynamic> toMap() => {
    'pacienteId': pacienteId,
    'profissionalId': profissionalId,
    'profissionalNome': profissionalNome,
    'data': gravarData(data),
    'subjetivo': subjetivo,
    'objetivo': objetivo,
    'avaliacao': avaliacao,
    'plano': plano,
    'acolhimento': acolhimento,
    'acertos': acertos,
    'tentativas': tentativas,
    'finalizada': finalizada,
    'sessaoNumero': sessaoNumero,
  };

  factory Evolucao.fromMap(String id, Map<String, dynamic> m) => Evolucao(
    id: id,
    pacienteId: m['pacienteId'] as String? ?? '',
    profissionalId: m['profissionalId'] as String? ?? '',
    profissionalNome: m['profissionalNome'] as String? ?? '',
    data: lerData(m['data']),
    subjetivo: m['subjetivo'] as String? ?? '',
    objetivo: m['objetivo'] as String? ?? '',
    avaliacao: m['avaliacao'] as String? ?? '',
    plano: m['plano'] as String? ?? '',
    acolhimento: m['acolhimento'] as String? ?? '',
    acertos: (m['acertos'] as num?)?.toInt() ?? 0,
    tentativas: (m['tentativas'] as num?)?.toInt() ?? 0,
    finalizada: m['finalizada'] as bool? ?? false,
    sessaoNumero: (m['sessaoNumero'] as num?)?.toInt() ?? 0,
  );
}
