import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonoclin/core/perf.dart';
import 'package:fonoclin/core/tema.dart';
import 'package:fonoclin/dados/banco_dados.dart';
import 'package:fonoclin/dados/clinica_repositorio.dart';
import 'package:fonoclin/dados/dados_demo.dart';
import 'package:fonoclin/logica/resumo_financeiro.dart';
import 'package:fonoclin/telas/dono/financeiro_tela.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'ajudantes.dart';

/// Testes das otimizações de desempenho (ver PERFORMANCE.md).
void main() {
  final agora = DateTime(2026, 11, 24, 10);

  setUpAll(() async {
    TemaApp.fontesWeb = false;
    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  tearDown(() => Perf.otimizado = true);

  test('consulta por intervalo devolve só os agendamentos da semana', () async {
    final banco = MemoriaBanco();
    for (final a in [
      ag('antes', DateTime(2026, 1, 4, 9)),
      ag('seg', DateTime(2026, 1, 5, 8, 30)),
      ag('sex', DateTime(2026, 1, 9, 16)),
      ag('depois', DateTime(2026, 1, 12, 8, 30)),
    ]) {
      await banco.gravar(Colecoes.agendamentos, a.id, a.toMap());
    }
    final semana = await ClinicaRepositorio(banco)
        .agendamentosEntre(DateTime(2026, 1, 5), DateTime(2026, 1, 12))
        .first;
    expect(semana.map((a) => a.id), ['seg', 'sex']);
  });

  test('modo estresse acrescenta a massa de dados pedida', () async {
    final base = MemoriaBanco();
    final estresse = MemoriaBanco();
    await popularDadosDemo(base, agora: agora);
    await popularDadosDemo(estresse, agora: agora, estresse: 1000);

    Future<int> contar(BancoDados b, String c) async =>
        (await b.buscar(c)).length;
    expect(
      await contar(estresse, Colecoes.cobrancas) -
          await contar(base, Colecoes.cobrancas),
      1000,
    );
    expect(
      await contar(estresse, Colecoes.agendamentos) -
          await contar(base, Colecoes.agendamentos),
      1000,
    );
  });

  test('custo do resumo financeiro com 5.000 cobranças', () {
    final mes = DateTime(agora.year, agora.month);
    final cobrancas = [
      for (var i = 0; i < 5000; i++)
        cob(
          'c$i',
          150,
          DateTime(agora.year, agora.month, 1 + i % 28),
          pagoEm: i.isEven
              ? DateTime(agora.year, agora.month, 1 + i % 28)
              : null,
        ),
    ];
    final relogio = Stopwatch()..start();
    final r = ResumoFinanceiro.calcular(cobrancas, mes: mes, hoje: agora);
    relogio.stop();
    // Este é o custo que a versão "antes" paga na thread de UI a cada
    // rebuild (cada tecla na busca, cada troca de filtro).
    // ignore: avoid_print
    print('ResumoFinanceiro.calcular(5000): ${relogio.elapsedMicroseconds} µs');
    expect(r.lancamentos, hasLength(5000));
  });

  Future<int> cartoesConstruidos(WidgetTester tester) async {
    // Largura de tablet: a fonte de teste (Ahem) é bem mais larga que a real.
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ClinicaRepositorio repo;
    await tester.runAsync(() async {
      final banco = MemoriaBanco();
      await popularDadosDemo(banco, estresse: 2000);
      repo = ClinicaRepositorio(banco);
    });

    final relogio = Stopwatch()..start();
    await tester.pumpWidget(
      Provider<ClinicaRepositorio>.value(
        value: repo,
        child: MaterialApp(
          theme: TemaApp.claro(),
          home: const Scaffold(body: FinanceiroTela()),
        ),
      ),
    );
    // A versão otimizada calcula o resumo num Isolate: espera ele voltar.
    for (
      var i = 0;
      i < 100 && find.byType(Scrollable).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    relogio.stop();

    // Rola até a lista, para os cartões entrarem na tela.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await tester.pump();

    final n = find
        .byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_CartaoLancamento',
          skipOffstage: false,
        )
        .evaluate()
        .length;
    // ignore: avoid_print
    print(
      '${Perf.otimizado ? 'DEPOIS' : 'ANTES '}: $n cartões construídos '
      '(${relogio.elapsedMilliseconds} ms no teste, modo debug)',
    );
    return n;
  }

  testWidgets('ANTES: a lista do financeiro constrói todos os cartões', (
    tester,
  ) async {
    Perf.otimizado = false;
    expect(await cartoesConstruidos(tester), greaterThan(2000));
  });

  testWidgets('DEPOIS: a lista do financeiro só constrói os visíveis', (
    tester,
  ) async {
    Perf.otimizado = true;
    final n = await cartoesConstruidos(tester);
    expect(n, greaterThan(0));
    expect(n, lessThan(30));
  });
}
