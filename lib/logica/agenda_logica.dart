import '../core/formatos.dart';
import '../modelos/agendamento.dart';

class Disponibilidade {
  const Disponibilidade({
    required this.profissionalLivre,
    required this.salaLivre,
    this.conflitos = const [],
  });

  final bool profissionalLivre;
  final bool salaLivre;
  final List<Agendamento> conflitos;

  bool get livre => profissionalLivre && salaLivre;
}

abstract final class AgendaLogica {
  static List<Agendamento> doDia(List<Agendamento> todos, DateTime dia) =>
      todos.where((a) => a.inicio.mesmoDia(dia)).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  // ignorarId = o próprio agendamento que tá sendo movido
  static Disponibilidade verificar(
    List<Agendamento> todos, {
    required String profissionalId,
    required String sala,
    required DateTime inicio,
    required DateTime fim,
    String? ignorarId,
  }) {
    final conflitos = todos
        .where(
          (a) =>
              a.id != ignorarId &&
              a.status.ativo &&
              a.sobrepoe(inicio, fim) &&
              (a.profissionalId == profissionalId || a.sala == sala),
        )
        .toList();
    return Disponibilidade(
      profissionalLivre: !conflitos.any(
        (a) => a.profissionalId == profissionalId,
      ),
      salaLivre: !conflitos.any((a) => a.sala == sala),
      conflitos: conflitos,
    );
  }

  static List<DateTime> horariosLivres(
    List<Agendamento> todos,
    DateTime dia, {
    required String profissionalId,
  }) {
    final ocupados = todos.where(
      (a) =>
          a.profissionalId == profissionalId &&
          a.status.ativo &&
          a.inicio.mesmoDia(dia),
    );
    return [
      for (final (h, m) in Salas.grade)
        if (!ocupados.any(
          (a) => a.sobrepoe(
            dia.comHora(h, m),
            dia
                .comHora(h, m)
                .add(const Duration(minutes: Salas.duracaoPadraoMin)),
          ),
        ))
          dia.comHora(h, m),
    ];
  }

  static Agendamento? proxima(List<Agendamento> doPaciente, DateTime agora) {
    final futuras =
        doPaciente
            .where((a) => a.status.ativo && !a.status.encerrado)
            .where((a) => a.fim.isAfter(agora))
            .toList()
          ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return futuras.isEmpty ? null : futuras.first;
  }

  static DateTime inicioDaSemana(DateTime dia) =>
      dia.inicioDoDia.subtract(Duration(days: dia.weekday - DateTime.monday));

  // ISO 8601
  static int numeroDaSemana(DateTime dia) {
    final quinta = dia.add(Duration(days: DateTime.thursday - dia.weekday));
    final primeiroDia = DateTime(quinta.year, 1, 1);
    return ((quinta.difference(primeiroDia).inDays) / 7).floor() + 1;
  }
}
