import 'conversao.dart';

/// Ciclo de vida de um atendimento:
/// agendado → confirmado → naRecepcao → emAtendimento → concluido
/// (ou faltou / cancelado).
enum StatusAgendamento {
  agendado('Agendado'),
  confirmado('Confirmado'),
  naRecepcao('Na recepção'),
  emAtendimento('Em atendimento'),
  concluido('Concluído'),
  faltou('Faltou'),
  cancelado('Cancelado');

  const StatusAgendamento(this.rotulo);
  final String rotulo;

  bool get ativo =>
      this != StatusAgendamento.cancelado && this != StatusAgendamento.faltou;
  bool get encerrado =>
      this == StatusAgendamento.concluido ||
      this == StatusAgendamento.faltou ||
      this == StatusAgendamento.cancelado;
}

/// Salas físicas da clínica.
abstract final class Salas {
  static const todas = [
    'Sala 01 - Linguagem e Fala',
    'Sala 02 - Lúdica',
    'Cabine Audiometria',
  ];

  /// Grade padrão de horários (início) de cada dia.
  static const grade = [
    (8, 30),
    (10, 0),
    (11, 30),
    (14, 0),
    (15, 30),
    (16, 30),
  ];

  static const duracaoPadraoMin = 45;
}

/// Um horário marcado na agenda (`agendamentos/{id}`).
class Agendamento {
  const Agendamento({
    required this.id,
    required this.pacienteId,
    required this.pacienteNome,
    required this.pacienteNascimento,
    required this.profissionalId,
    required this.profissionalNome,
    required this.sala,
    required this.inicio,
    required this.fim,
    this.tipo = 'Terapia',
    this.status = StatusAgendamento.agendado,
    this.chegadaEm,
    this.iniciadoEm,
    this.chegadaPor = '',
    this.sessaoNumero = 0,
    this.evolucaoSalva = false,
    this.whatsappConfirmado = false,
  });

  final String id;
  final String pacienteId;
  final String pacienteNome;
  final DateTime pacienteNascimento;
  final String profissionalId;
  final String profissionalNome;
  final String sala;
  final DateTime inicio;
  final DateTime fim;

  /// Terapia, Avaliação, Avaliação Audiológica, Retorno…
  final String tipo;
  final StatusAgendamento status;
  final DateTime? chegadaEm;
  final DateTime? iniciadoEm;
  final String chegadaPor;
  final int sessaoNumero;
  final bool evolucaoSalva;
  final bool whatsappConfirmado;

  Duration get duracao => fim.difference(inicio);

  bool sobrepoe(DateTime outroInicio, DateTime outroFim) =>
      inicio.isBefore(outroFim) && outroInicio.isBefore(fim);

  Agendamento copyWith({
    DateTime? inicio,
    DateTime? fim,
    StatusAgendamento? status,
    DateTime? chegadaEm,
    DateTime? iniciadoEm,
    String? chegadaPor,
    bool? evolucaoSalva,
  }) => Agendamento(
    id: id,
    pacienteId: pacienteId,
    pacienteNome: pacienteNome,
    pacienteNascimento: pacienteNascimento,
    profissionalId: profissionalId,
    profissionalNome: profissionalNome,
    sala: sala,
    inicio: inicio ?? this.inicio,
    fim: fim ?? this.fim,
    tipo: tipo,
    status: status ?? this.status,
    chegadaEm: chegadaEm ?? this.chegadaEm,
    iniciadoEm: iniciadoEm ?? this.iniciadoEm,
    chegadaPor: chegadaPor ?? this.chegadaPor,
    sessaoNumero: sessaoNumero,
    evolucaoSalva: evolucaoSalva ?? this.evolucaoSalva,
    whatsappConfirmado: whatsappConfirmado,
  );

  Map<String, dynamic> toMap() => {
    'pacienteId': pacienteId,
    'pacienteNome': pacienteNome,
    'pacienteNascimento': gravarData(pacienteNascimento),
    'profissionalId': profissionalId,
    'profissionalNome': profissionalNome,
    'sala': sala,
    'inicio': gravarData(inicio),
    'fim': gravarData(fim),
    'tipo': tipo,
    'status': status.name,
    'chegadaEm': gravarDataOpcional(chegadaEm),
    'iniciadoEm': gravarDataOpcional(iniciadoEm),
    'chegadaPor': chegadaPor,
    'sessaoNumero': sessaoNumero,
    'evolucaoSalva': evolucaoSalva,
    'whatsappConfirmado': whatsappConfirmado,
  };

  factory Agendamento.fromMap(String id, Map<String, dynamic> m) {
    final inicio = lerData(m['inicio']);
    return Agendamento(
      id: id,
      pacienteId: m['pacienteId'] as String? ?? '',
      pacienteNome: m['pacienteNome'] as String? ?? '',
      pacienteNascimento: lerData(m['pacienteNascimento']),
      profissionalId: m['profissionalId'] as String? ?? '',
      profissionalNome: m['profissionalNome'] as String? ?? '',
      sala: m['sala'] as String? ?? '',
      inicio: inicio,
      fim: lerData(
        m['fim'],
        inicio.add(const Duration(minutes: Salas.duracaoPadraoMin)),
      ),
      tipo: m['tipo'] as String? ?? 'Terapia',
      status: lerEnum(
        StatusAgendamento.values,
        m['status'],
        StatusAgendamento.agendado,
      ),
      chegadaEm: lerDataOpcional(m['chegadaEm']),
      iniciadoEm: lerDataOpcional(m['iniciadoEm']),
      chegadaPor: m['chegadaPor'] as String? ?? '',
      sessaoNumero: (m['sessaoNumero'] as num?)?.toInt() ?? 0,
      evolucaoSalva: m['evolucaoSalva'] as bool? ?? false,
      whatsappConfirmado: m['whatsappConfirmado'] as bool? ?? false,
    );
  }
}
