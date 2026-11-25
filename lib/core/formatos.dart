import 'package:intl/intl.dart';

/// Funções de formatação em português do Brasil.
abstract final class Formatos {
  static final _hora = DateFormat('HH:mm', 'pt_BR');
  static final _diaMes = DateFormat('dd/MM', 'pt_BR');
  static final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _mesAno = DateFormat('MMMM yyyy', 'pt_BR');
  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  static String hora(DateTime d) => _hora.format(d);
  static String diaMes(DateTime d) => _diaMes.format(d);
  static String data(DateTime d) => _data.format(d);
  static String mesAno(DateTime d) => capitalizar(_mesAno.format(d));
  static String moeda(num valor) => _moeda.format(valor);

  /// "R$ 38.600" (sem centavos) e ",00" separados, como no design.
  static (String inteiro, String centavos) moedaPartes(num valor) {
    final texto = _moeda.format(valor);
    final i = texto.lastIndexOf(',');
    return (texto.substring(0, i), texto.substring(i));
  }

  static String diaSemana(DateTime d) =>
      capitalizar(DateFormat('EEEE', 'pt_BR').format(d));

  static String diaSemanaCurto(DateTime d) {
    final s = DateFormat('EEE', 'pt_BR').format(d).replaceAll('.', '');
    return capitalizar(s);
  }

  static String mesCurto(DateTime d) {
    final s = DateFormat('MMM', 'pt_BR').format(d).replaceAll('.', '');
    return capitalizar(s);
  }

  /// "Quarta-feira, 24 Out"
  static String diaCompleto(DateTime d) =>
      '${diaSemana(d)}, ${d.day} ${mesCurto(d)}';

  /// "Sex, 26/10 às 15:00"
  static String diaHoraCurto(DateTime d) =>
      '${diaSemanaCurto(d)}, ${diaMes(d)} às ${hora(d)}';

  static String capitalizar(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String iniciais(String nome) {
    final partes = nome
        .replaceAll(RegExp(r'^(Dra?\.)\s*'), '')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  static String primeiroNome(String nome) {
    final semTitulo = nome.replaceAll(RegExp(r'^(Dra?\.)\s*'), '');
    return semTitulo.split(' ').first;
  }

  /// "há 22 min", "há 3 h", "há 2 dias"
  static String tempoDecorrido(DateTime desde, DateTime agora) {
    final d = agora.difference(desde);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    return 'há ${d.inDays} ${d.inDays == 1 ? 'dia' : 'dias'}';
  }

  static int idade(DateTime nascimento, DateTime hoje) {
    var anos = hoje.year - nascimento.year;
    final fezAniversario =
        hoje.month > nascimento.month ||
        (hoje.month == nascimento.month && hoje.day >= nascimento.day);
    if (!fezAniversario) anos--;
    return anos;
  }

  static String idadeTexto(DateTime nascimento, DateTime hoje) {
    final anos = idade(nascimento, hoje);
    if (anos >= 18) return 'Adulto';
    return '$anos ${anos == 1 ? 'ano' : 'anos'}';
  }
}

extension DataUtil on DateTime {
  DateTime get inicioDoDia => DateTime(year, month, day);
  bool mesmoDia(DateTime o) =>
      year == o.year && month == o.month && day == o.day;
  DateTime comHora(int h, int m) => DateTime(year, month, day, h, m);
}
