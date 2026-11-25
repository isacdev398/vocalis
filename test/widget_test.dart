import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fonoclin/app.dart';
import 'package:fonoclin/core/tema.dart';
import 'package:fonoclin/dados/dados_demo.dart';
import 'package:fonoclin/estado/sessao.dart';
import 'package:fonoclin/modelos/usuario.dart';
import 'package:fonoclin/rotas.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    TemaApp.fontesWeb = false; // sem download de fontes nos testes
    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  Future<Sessao> abrirApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Sessao sessao;
    await tester.runAsync(() async {
      sessao = Sessao(criarDemo: () => Backend.demonstracao());
      await sessao.iniciar();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpWidget(FonoGestaoApp(sessao: sessao));
    await tester.pumpAndSettle();
    return sessao;
  }

  testWidgets('login valida os campos antes de enviar', (tester) async {
    await abrirApp(tester);
    expect(find.text('Vocalis'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-email')), 'ana@');
    await tester.enterText(find.byKey(const Key('campo-senha')), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(find.text('Mínimo de 6 caracteres'), findsOneWidget);
  });

  testWidgets('senha errada mostra mensagem de erro', (tester) async {
    await abrirApp(tester);
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'juliana@vocalis.demo',
    );
    await tester.enterText(find.byKey(const Key('campo-senha')), 'errada1');
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('cliente entra e vê o Portal do Cliente', (tester) async {
    await abrirApp(tester);
    await tester.enterText(
      find.byKey(const Key('campo-email')),
      'juliana@vocalis.demo',
    );
    await tester.enterText(
      find.byKey(const Key('campo-senha')),
      ContasDemo.senha,
    );
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Olá, Juliana'), findsOneWidget);
    expect(find.text('Portal do Cliente'), findsOneWidget);
    expect(find.textContaining('Maitê Silva'), findsWidgets);
    expect(find.text('Exercícios'), findsOneWidget);
    expect(find.text('Financeiro'), findsNothing);
  });

  test('controle de acesso por perfil', () {
    const recepcao = Usuario(
      id: 'r',
      nome: 'Camila',
      email: 'c@x.com',
      perfil: Perfil.recepcao,
      permissoes: Permissoes(agenda: true, cobranca: true),
    );
    const fonoSemCrfa = Usuario(
      id: 'f',
      nome: 'Fono',
      email: 'f@x.com',
      perfil: Perfil.fono,
      permissoes: Permissoes(agenda: true, clinico: true),
    );
    const cliente = Usuario(
      id: 'c',
      nome: 'Juliana',
      email: 'j@x.com',
      perfil: Perfil.cliente,
    );

    expect(Rotas.podeAcessar(recepcao, Rotas.agenda), isTrue);
    expect(Rotas.podeAcessar(recepcao, Rotas.financeiro), isTrue);
    expect(Rotas.podeAcessar(recepcao, Rotas.atendimento('1')), isFalse);
    expect(Rotas.podeAcessar(recepcao, Rotas.equipe), isFalse);
    // sem CRFa não abre prontuário mesmo com a permissão
    expect(Rotas.podeAcessar(fonoSemCrfa, Rotas.atendimento('1')), isFalse);
    expect(Rotas.podeAcessar(cliente, Rotas.cliente), isTrue);
    expect(Rotas.podeAcessar(cliente, Rotas.agenda), isFalse);
    expect(Rotas.inicio(cliente), Rotas.cliente);
  });
}
