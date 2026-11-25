import 'conversao.dart';

enum StatusSolicitacao { pendente, aprovada, recusada }

// pedido de troca de horário (cliente pede, recepção avalia)
class SolicitacaoReagendamento {
  const SolicitacaoReagendamento({
    required this.id,
    required this.agendamentoId,
    required this.pacienteId,
    required this.pacienteNome,
    required this.responsavelNome,
    required this.profissionalId,
    required this.profissionalNome,
    required this.sala,
    required this.horarioAtual,
    required this.horarioPretendido,
    required this.criadoEm,
    this.motivo = '',
    this.status = StatusSolicitacao.pendente,
    this.protocolo = '',
    this.resolvidoPor = '',
    this.resolvidoEm,
    this.horarioFinal,
  });

  final String id;
  final String agendamentoId;
  final String pacienteId;
  final String pacienteNome;
  final String responsavelNome;
  final String profissionalId;
  final String profissionalNome;
  final String sala;
  final DateTime horarioAtual;
  final DateTime horarioPretendido;
  final DateTime criadoEm;
  final String motivo;
  final StatusSolicitacao status;
  final String protocolo;
  final String resolvidoPor;
  final DateTime? resolvidoEm;

  // pode ser diferente do que o cliente pediu
  final DateTime? horarioFinal;

  bool get pendente => status == StatusSolicitacao.pendente;

  Map<String, dynamic> toMap() => {
    'agendamentoId': agendamentoId,
    'pacienteId': pacienteId,
    'pacienteNome': pacienteNome,
    'responsavelNome': responsavelNome,
    'profissionalId': profissionalId,
    'profissionalNome': profissionalNome,
    'sala': sala,
    'horarioAtual': gravarData(horarioAtual),
    'horarioPretendido': gravarData(horarioPretendido),
    'criadoEm': gravarData(criadoEm),
    'motivo': motivo,
    'status': status.name,
    'protocolo': protocolo,
    'resolvidoPor': resolvidoPor,
    'resolvidoEm': gravarDataOpcional(resolvidoEm),
    'horarioFinal': gravarDataOpcional(horarioFinal),
  };

  factory SolicitacaoReagendamento.fromMap(String id, Map<String, dynamic> m) =>
      SolicitacaoReagendamento(
        id: id,
        agendamentoId: m['agendamentoId'] as String? ?? '',
        pacienteId: m['pacienteId'] as String? ?? '',
        pacienteNome: m['pacienteNome'] as String? ?? '',
        responsavelNome: m['responsavelNome'] as String? ?? '',
        profissionalId: m['profissionalId'] as String? ?? '',
        profissionalNome: m['profissionalNome'] as String? ?? '',
        sala: m['sala'] as String? ?? '',
        horarioAtual: lerData(m['horarioAtual']),
        horarioPretendido: lerData(m['horarioPretendido']),
        criadoEm: lerData(m['criadoEm']),
        motivo: m['motivo'] as String? ?? '',
        status: lerEnum(
          StatusSolicitacao.values,
          m['status'],
          StatusSolicitacao.pendente,
        ),
        protocolo: m['protocolo'] as String? ?? '',
        resolvidoPor: m['resolvidoPor'] as String? ?? '',
        resolvidoEm: lerDataOpcional(m['resolvidoEm']),
        horarioFinal: lerDataOpcional(m['horarioFinal']),
      );
}
