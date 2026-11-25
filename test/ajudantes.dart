import 'package:fonoclin/modelos/agendamento.dart';
import 'package:fonoclin/modelos/cobranca.dart';

/// Cria agendamentos curtos para os testes.
Agendamento ag(
  String id,
  DateTime inicio, {
  String profissional = 'ana',
  String sala = 'Sala A',
  String paciente = 'p1',
  StatusAgendamento status = StatusAgendamento.agendado,
  int minutos = 45,
}) => Agendamento(
  id: id,
  pacienteId: paciente,
  pacienteNome: 'Paciente $paciente',
  pacienteNascimento: DateTime(2018, 5, 10),
  profissionalId: profissional,
  profissionalNome: 'Dra. $profissional',
  sala: sala,
  inicio: inicio,
  fim: inicio.add(Duration(minutes: minutos)),
  status: status,
);

Cobranca cob(
  String id,
  double valor,
  DateTime vencimento, {
  DateTime? pagoEm,
  FormaPagamento? forma,
  String paciente = 'p1',
}) => Cobranca(
  id: id,
  pacienteId: paciente,
  pacienteNome: 'Paciente $paciente',
  descricao: 'Sessão',
  valor: valor,
  vencimento: vencimento,
  pagoEm: pagoEm,
  forma: forma ?? (pagoEm == null ? null : FormaPagamento.pix),
);
