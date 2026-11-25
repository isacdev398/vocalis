import 'package:flutter_test/flutter_test.dart';
import 'package:fonoclin/core/formatos.dart';
import 'package:fonoclin/dados/banco_dados.dart';
import 'package:fonoclin/dados/clinica_repositorio.dart';
import 'package:fonoclin/dados/dados_demo.dart';
import 'package:fonoclin/estado/sessao.dart';
import 'package:fonoclin/modelos/agendamento.dart';
import 'package:fonoclin/modelos/cobranca.dart';
import 'package:fonoclin/modelos/evolucao.dart';
import 'package:fonoclin/modelos/exercicio.dart';
import 'package:fonoclin/modelos/solicitacao.dart';
import 'package:fonoclin/modelos/usuario.dart';
import 'package:fonoclin/servicos/auth_servico.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'ajudantes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Modelos (ida e volta pelo Firestore)', () {
    test('Agendamento preserva todos os campos', () {
      final a = ag(
        'x',
        DateTime(2026, 10, 21, 14),
      ).copyWith(status: StatusAgendamento.naRecepcao, chegadaPor: 'Camila');
      final b = Agendamento.fromMap('x', a.toMap());
      expect(b.inicio, a.inicio);
      expect(b.fim, a.fim);
      expect(b.status, StatusAgendamento.naRecepcao);
      expect(b.chegadaPor, 'Camila');
    });

    test('Usuario e permissões', () {
      const u = Usuario(
        id: 'u',
        nome: 'Dra. Ana Costa',
        email: 'ana@x.com',
        perfil: Perfil.fono,
        registro: 'CRFa 2-19402',
        permissoes: Permissoes(agenda: true, clinico: true),
      );
      final v = Usuario.fromMap('u', u.toMap());
      expect(v.perfil, Perfil.fono);
      expect(v.permissoes, u.permissoes);
      expect(v.ehProfissionalClinico, isTrue);
    });

    test('Cobrança: situação depende do dia', () {
      final c = cob('c', 100, DateTime(2026, 10, 20));
      expect(c.situacao(DateTime(2026, 10, 20, 23)), SituacaoCobranca.pendente);
      expect(c.situacao(DateTime(2026, 10, 21)), SituacaoCobranca.atrasada);
      expect(c.diasDeAtraso(DateTime(2026, 10, 26)), 6);
    });

    test('Evolução calcula a precisão', () {
      final e = Evolucao(
        id: 'e',
        pacienteId: 'p',
        profissionalId: 'ana',
        profissionalNome: 'Ana',
        data: DateTime(2026),
        acertos: 16,
        tentativas: 20,
      );
      expect(e.precisaoPercentual, 80);
      expect(Evolucao.fromMap('e', e.toMap()).precisao, 0.8);
    });

    test('Estímulo separa sílabas simples', () {
      expect(const Estimulo('sapato').silabas, 'sa-pa-to');
      expect(const Estimulo('sino').silabas, 'si-no');
    });
  });

  group('MemoriaBanco', () {
    test('stream emite o estado atual e cada mudança', () async {
      final b = MemoriaBanco();
      final emissoes = <int>[];
      final sub = b.colecao('x').listen((l) => emissoes.add(l.length));
      await pumpEventQueue();
      await b.gravar('x', '1', {'n': 1});
      await b.gravar('x', '2', {'n': 2});
      await pumpEventQueue();
      expect(emissoes, [0, 1, 2]);
      await sub.cancel();
    });

    test('incremento soma no valor existente', () async {
      final b = MemoriaBanco();
      await b.gravar('p', 'a', {'estrelas': 3});
      await b.atualizar('p', 'a', {'estrelas': const Incremento(2)});
      expect((await b.buscar('p')).single.dados['estrelas'], 5);
    });

    test('lote é tudo ou nada', () async {
      final b = MemoriaBanco();
      await b.gravar('p', 'a', {'v': 1});
      await expectLater(
        b.lote([
          const Atualizar('p', 'a', {'v': 2}),
          const Atualizar('p', 'nao-existe', {'v': 3}),
        ]),
        throwsStateError,
      );
      expect((await b.buscar('p')).single.dados['v'], 1);
    });

    test('filtro por igualdade', () async {
      final b = MemoriaBanco();
      await b.lote([
        const Gravar('c', '1', {'pacienteId': 'a'}),
        const Gravar('c', '2', {'pacienteId': 'b'}),
      ]);
      final l = await b.colecao('c', campo: 'pacienteId', igualA: 'b').first;
      expect(l.map((d) => d.id), ['2']);
    });
  });

  group('ClinicaRepositorio', () {
    late MemoriaBanco db;
    late ClinicaRepositorio repo;
    final hoje = DateTime(2026, 10, 21, 9);

    setUp(() async {
      db = MemoriaBanco();
      await popularDadosDemo(db, agora: hoje);
      repo = ClinicaRepositorio(db);
    });

    test('dados da demonstração são gravados', () async {
      final equipe = await repo.equipe().first;
      expect(equipe.map((u) => u.nome), contains('Dra. Ana Costa'));
      expect(equipe.where((u) => u.perfil == Perfil.cliente), isEmpty);
      expect((await repo.profissionais().first).length, 3);

      final hojeAgenda = (await repo.agendamentos().first)
          .where((a) => a.inicio.mesmoDia(hoje))
          .toList();
      expect(hojeAgenda.length, 8);
      expect(
        (await repo.solicitacoes().first).where((s) => s.pendente).length,
        1,
      );
    });

    test('aprovar reagendamento move o horário e fecha o pedido', () async {
      final s = (await repo.solicitacoes().first).firstWhere((s) => s.pendente);
      await repo.aprovarSolicitacao(
        s,
        novoInicio: s.horarioPretendido,
        duracao: const Duration(minutes: 45),
        por: 'Camila Rocha',
      );
      final a = await repo.agendamento(s.agendamentoId).first;
      expect(a!.inicio, s.horarioPretendido);
      expect(a.status, StatusAgendamento.confirmado);
      final depois = await repo.solicitacao(s.id).first;
      expect(depois!.status, StatusSolicitacao.aprovada);
      expect(depois.resolvidoPor, 'Camila Rocha');
    });

    test('finalizar evolução conclui o atendimento', () async {
      const id = 'ag-hoje-maite';
      await repo.iniciarAtendimento(id);
      expect(
        (await repo.agendamento(id).first)!.status,
        StatusAgendamento.emAtendimento,
      );
      await repo.finalizarEvolucao(
        Evolucao(
          id: id,
          pacienteId: 'p-maite',
          profissionalId: ContasDemo.ana,
          profissionalNome: 'Dra. Ana Costa',
          data: hoje,
          subjetivo: 's',
          objetivo: 'o',
          avaliacao: 'a',
          plano: 'p',
        ),
      );
      final a = await repo.agendamento(id).first;
      expect(a!.status, StatusAgendamento.concluido);
      expect(a.evolucaoSalva, isTrue);
      expect((await repo.evolucao(id).first)!.finalizada, isTrue);
    });

    test('registrar prática soma estrela e conclui ao bater a meta', () async {
      var ex = (await repo.exerciciosDoPaciente('p-maite').first).firstWhere(
        (e) => e.id == 'ex-maite-s',
      );
      expect((ex.praticasSemana, ex.metaSemanal), (2, 4));
      await repo.registrarPratica(ex);
      ex = (await repo.exerciciosDoPaciente('p-maite').first).firstWhere(
        (e) => e.id == 'ex-maite-s',
      );
      expect(ex.concluido, isFalse);
      await repo.registrarPratica(ex);
      ex = (await repo.exerciciosDoPaciente('p-maite').first).firstWhere(
        (e) => e.id == 'ex-maite-s',
      );
      expect(ex.concluido, isTrue);
      expect((await repo.paciente('p-maite').first)!.estrelas, 16);
    });

    test('dar baixa em cobrança', () async {
      await repo.registrarPagamento('mens-p-maite', FormaPagamento.cartao);
      final c = (await repo.cobrancasDoPaciente('p-maite').first).firstWhere(
        (c) => c.id == 'mens-p-maite',
      );
      expect(c.paga, isTrue);
      expect(c.forma, FormaPagamento.cartao);
    });

    test('atualizar permissões', () async {
      await repo.atualizarPermissoes(
        ContasDemo.camila,
        const Permissoes(agenda: true),
      );
      final u = await repo.usuario(ContasDemo.camila).first;
      expect(u!.permissoes.cobranca, isFalse);
    });
  });

  group('Sessao', () {
    Future<Sessao> novaSessao() async {
      final s = Sessao(criarDemo: () => Backend.demonstracao());
      await s.iniciar();
      await pumpEventQueue();
      return s;
    }

    test('começa deslogada e entra com conta de demonstração', () async {
      final s = await novaSessao();
      expect(s.estado, EstadoSessao.deslogado);
      expect(s.emDemonstracao, isTrue);

      await s.entrar('ana@vocalis.demo', ContasDemo.senha);
      await pumpEventQueue();
      expect(s.estado, EstadoSessao.logado);
      expect(s.usuario!.perfil, Perfil.fono);

      await s.sair();
      await pumpEventQueue();
      expect(s.estado, EstadoSessao.deslogado);
      expect(s.usuario, isNull);
    });

    test('senha errada gera erro amigável', () async {
      final s = await novaSessao();
      expect(
        () => s.entrar('ana@vocalis.demo', 'errada'),
        throwsA(
          isA<AuthErro>().having(
            (e) => e.mensagem,
            'mensagem',
            'E-mail ou senha incorretos.',
          ),
        ),
      );
    });

    test('cadastro de cliente cria usuário e paciente vinculados', () async {
      final s = await novaSessao();
      await s.cadastrar(
        nome: 'Paula Souza',
        email: 'paula@exemplo.com',
        senha: '123456',
        perfil: Perfil.cliente,
        nomePaciente: 'Bento Souza',
        nascimentoPaciente: DateTime(2019, 3, 2),
        parentesco: 'Mãe',
      );
      await pumpEventQueue();
      final u = s.usuario!;
      expect(u.perfil, Perfil.cliente);
      expect(u.pacienteId, isNotNull);
      final p = await s.repo.paciente(u.pacienteId!).first;
      expect(p!.nome, 'Bento Souza');
      expect(p.responsavelNome, 'Paula Souza');
    });

    test('convite define o perfil no cadastro', () async {
      final s = await novaSessao();
      await s.repo.convidarColaborador(
        nome: 'Julia Prado',
        email: 'julia@clinica.com',
        perfil: Perfil.fono,
        cargo: 'Fonoaudióloga',
        registro: 'CRFa 2-11111',
      );
      await s.cadastrar(
        nome: 'Julia Prado',
        email: 'julia@clinica.com',
        senha: '123456',
        perfil: Perfil.cliente, // escolha ignorada: vale o convite
      );
      await pumpEventQueue();
      expect(s.usuario!.perfil, Perfil.fono);
      expect(s.usuario!.registro, 'CRFa 2-11111');
      final equipe = await s.repo.equipe().first;
      expect(equipe.where((u) => u.email == 'julia@clinica.com').length, 1);
    });

    test('seletor de perfis entra direto como o personagem', () async {
      final s = await novaSessao();
      final u = await s.entrarNaDemonstracao(ContasDemo.kariny);
      expect(u.perfil, Perfil.dono);
      expect(s.estado, EstadoSessao.logado);
    });
  });
}
