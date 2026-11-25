import 'package:flutter/foundation.dart';

import '../core/formatos.dart';
import '../logica/agenda_logica.dart';
import '../modelos/agendamento.dart';
import '../modelos/solicitacao.dart';

enum FiltroStatus { todos, pendentes, confirmados }

/// Estado da tela de Agenda (dia escolhido, filtros e busca).
/// Fica num ChangeNotifierProvider próprio da tela.
class AgendaController extends ChangeNotifier {
  AgendaController({DateTime? hoje, String? profissionalId})
    : _dia = (hoje ?? DateTime.now()).inicioDoDia,
      _profissionalId = profissionalId; // ignore: prefer_initializing_formals

  DateTime _dia;
  String? _profissionalId;
  FiltroStatus _status = FiltroStatus.todos;
  String _busca = '';

  DateTime get dia => _dia;
  DateTime get inicioSemana => AgendaLogica.inicioDaSemana(_dia);
  List<DateTime> get diasDaSemana => [
    for (var i = 0; i < 7; i++)
      DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day + i),
  ];
  String? get profissionalId => _profissionalId;
  FiltroStatus get status => _status;
  String get busca => _busca;

  void selecionarDia(DateTime d) {
    _dia = d.inicioDoDia;
    notifyListeners();
  }

  void mudarSemana(int delta) {
    _dia = DateTime(_dia.year, _dia.month, _dia.day + 7 * delta);
    notifyListeners();
  }

  void filtrarProfissional(String? id) {
    _profissionalId = id;
    notifyListeners();
  }

  void filtrarStatus(FiltroStatus s) {
    _status = s;
    notifyListeners();
  }

  void buscar(String texto) {
    _busca = texto;
    notifyListeners();
  }

  bool _combinaBusca(
    String paciente,
    String profissional, [
    String extra = '',
  ]) {
    final q = _semAcento(_busca.trim().toLowerCase());
    if (q.isEmpty) return true;
    return _semAcento('$paciente $profissional $extra'.toLowerCase())
        .contains(q);
  }

  /// Agendamentos do dia selecionado, com profissional, status e busca.
  List<Agendamento> filtrar(
    List<Agendamento> todos,
    List<SolicitacaoReagendamento> pendentes,
  ) {
    final comTroca = pendentes.map((s) => s.agendamentoId).toSet();
    return AgendaLogica.doDia(todos, _dia).where((a) {
      if (_profissionalId != null && a.profissionalId != _profissionalId) {
        return false;
      }
      if (!_combinaBusca(a.pacienteNome, a.profissionalNome)) return false;
      return switch (_status) {
        FiltroStatus.todos => true,
        FiltroStatus.pendentes =>
          a.status == StatusAgendamento.agendado || comTroca.contains(a.id),
        FiltroStatus.confirmados =>
          a.status != StatusAgendamento.agendado &&
              a.status.ativo &&
              !comTroca.contains(a.id),
      };
    }).toList();
  }

  /// Contagens para os chips (ignoram o filtro de status).
  ({int todos, int pendentes, int confirmados}) contagens(
    List<Agendamento> todos,
    List<SolicitacaoReagendamento> pendentes,
  ) {
    final atual = _status;
    _status = FiltroStatus.todos;
    final base = filtrar(todos, pendentes);
    final comTroca = pendentes.map((s) => s.agendamentoId).toSet();
    _status = atual;
    final pend = base
        .where(
          (a) =>
              a.status == StatusAgendamento.agendado || comTroca.contains(a.id),
        )
        .length;
    final conf = base
        .where(
          (a) =>
              a.status != StatusAgendamento.agendado &&
              a.status.ativo &&
              !comTroca.contains(a.id),
        )
        .length;
    return (todos: base.length, pendentes: pend, confirmados: conf);
  }

  List<SolicitacaoReagendamento> filtrarSolicitacoes(
    List<SolicitacaoReagendamento> pendentes,
  ) => pendentes
      .where(
        (s) =>
            (_profissionalId == null || s.profissionalId == _profissionalId) &&
            _combinaBusca(
              s.pacienteNome,
              s.profissionalNome,
              s.responsavelNome,
            ),
      )
      .toList();

  static String _semAcento(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? para[i] : ch);
    }
    return b.toString();
  }
}
