import '../modelos/agendamento.dart';
import '../modelos/cobranca.dart';
import '../modelos/conversao.dart';
import '../modelos/evolucao.dart';
import '../modelos/exercicio.dart';
import '../modelos/paciente.dart';
import '../modelos/solicitacao.dart';
import '../modelos/usuario.dart';
import 'banco_dados.dart';

abstract final class Colecoes {
  static const usuarios = 'usuarios';
  static const pacientes = 'pacientes';
  static const agendamentos = 'agendamentos';
  static const solicitacoes = 'solicitacoes';
  static const evolucoes = 'evolucoes';
  static const exercicios = 'exercicios';
  static const cobrancas = 'cobrancas';
}

// As telas só falam com o banco por aqui.
// Cada consulta tem no máx. um filtro e a ordenação é feita aqui,
// assim não precisa criar índice composto no Firebase.
class ClinicaRepositorio {
  ClinicaRepositorio(this.banco);

  final BancoDados banco;

  Stream<Usuario?> usuario(String uid) => banco
      .documento(Colecoes.usuarios, uid)
      .map((d) => d == null ? null : Usuario.fromMap(d.id, d.dados));

  Future<void> salvarUsuario(Usuario u) =>
      banco.gravar(Colecoes.usuarios, u.id, u.toMap());

  // todo mundo menos cliente; dono, fonos, recepção
  Stream<List<Usuario>> equipe() => banco.colecao(Colecoes.usuarios).map((l) {
    final lista = l
        .map((d) => Usuario.fromMap(d.id, d.dados))
        .where((u) => u.perfil != Perfil.cliente)
        .toList();
    const ordem = [Perfil.dono, Perfil.fono, Perfil.recepcao];
    // ignora o Dr./Dra. na ordem alfabética
    String chave(Usuario u) => u.nome.replaceFirst(RegExp(r'^Dra?\.\s*'), '');
    lista.sort((a, b) {
      final c = ordem.indexOf(a.perfil).compareTo(ordem.indexOf(b.perfil));
      return c != 0 ? c : chave(a).compareTo(chave(b));
    });
    return lista;
  });

  Stream<List<Usuario>> profissionais() => equipe().map(
    (l) => l.where((u) => u.ehProfissionalClinico && !u.convidado).toList(),
  );

  Future<void> atualizarPermissoes(String uid, Permissoes p) =>
      banco.atualizar(Colecoes.usuarios, uid, {'permissoes': p.toMap()});

  // convite: a pessoa cria a senha quando se cadastra com esse e-mail
  Future<void> convidarColaborador({
    required String nome,
    required String email,
    required Perfil perfil,
    required String cargo,
    String registro = '',
    String especialidade = '',
  }) {
    final id = banco.novoId(Colecoes.usuarios);
    return banco.gravar(
      Colecoes.usuarios,
      id,
      Usuario(
        id: id,
        nome: nome,
        email: email.trim().toLowerCase(),
        perfil: perfil,
        cargo: cargo,
        registro: registro,
        especialidade: especialidade,
        permissoes: Permissoes.padrao(perfil),
        convidado: true,
      ).toMap(),
    );
  }

  // apaga o doc do convite, o definitivo fica com o uid do Auth
  Future<Usuario?> vincularConvite(String email) async {
    final docs = await banco.buscar(
      Colecoes.usuarios,
      campo: 'email',
      igualA: email.trim().toLowerCase(),
    );
    for (final d in docs) {
      final u = Usuario.fromMap(d.id, d.dados);
      if (u.convidado) {
        await banco.apagar(Colecoes.usuarios, d.id);
        return u;
      }
    }
    return null;
  }

  Stream<List<Paciente>> pacientes() => banco
      .colecao(Colecoes.pacientes)
      .map(
        (l) =>
            l.map((d) => Paciente.fromMap(d.id, d.dados)).toList()
              ..sort((a, b) => a.nome.compareTo(b.nome)),
      );

  Stream<Paciente?> paciente(String id) => banco
      .documento(Colecoes.pacientes, id)
      .map((d) => d == null ? null : Paciente.fromMap(d.id, d.dados));

  Future<String> salvarPaciente(Paciente p) async {
    final id = p.id.isEmpty ? banco.novoId(Colecoes.pacientes) : p.id;
    await banco.gravar(Colecoes.pacientes, id, p.toMap());
    return id;
  }

  static List<Agendamento> _agendamentos(List<Documento> l) =>
      l.map((d) => Agendamento.fromMap(d.id, d.dados)).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  Stream<List<Agendamento>> agendamentos() =>
      banco.colecao(Colecoes.agendamentos).map(_agendamentos);

  // [de, ate) - agenda pede a semana, painel pede 2 meses
  Stream<List<Agendamento>> agendamentosEntre(DateTime de, DateTime ate) =>
      banco
          .colecaoEntre(
            Colecoes.agendamentos,
            campo: 'inicio',
            de: de,
            ate: ate,
          )
          .map(_agendamentos);

  Future<int> contarSessoesDoPaciente(String pacienteId) async =>
      (await banco.buscar(
        Colecoes.agendamentos,
        campo: 'pacienteId',
        igualA: pacienteId,
      )).length;

  Stream<List<Agendamento>> agendamentosDoPaciente(String pacienteId) => banco
      .colecao(Colecoes.agendamentos, campo: 'pacienteId', igualA: pacienteId)
      .map(_agendamentos);

  Stream<Agendamento?> agendamento(String id) => banco
      .documento(Colecoes.agendamentos, id)
      .map((d) => d == null ? null : Agendamento.fromMap(d.id, d.dados));

  Future<String> criarAgendamento(Agendamento a) async {
    final id = banco.novoId(Colecoes.agendamentos);
    await banco.gravar(Colecoes.agendamentos, id, a.toMap());
    return id;
  }

  Future<void> registrarChegada(String id, {required String por}) =>
      banco.atualizar(Colecoes.agendamentos, id, {
        'status': StatusAgendamento.naRecepcao.name,
        'chegadaEm': gravarData(DateTime.now()),
        'chegadaPor': por,
      });

  Future<void> iniciarAtendimento(String id) =>
      banco.atualizar(Colecoes.agendamentos, id, {
        'status': StatusAgendamento.emAtendimento.name,
        'iniciadoEm': gravarData(DateTime.now()),
      });

  Future<void> alterarStatus(String id, StatusAgendamento status) =>
      banco.atualizar(Colecoes.agendamentos, id, {'status': status.name});

  static List<SolicitacaoReagendamento> _solicitacoes(List<Documento> l) =>
      l.map((d) => SolicitacaoReagendamento.fromMap(d.id, d.dados)).toList()
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

  Stream<List<SolicitacaoReagendamento>> solicitacoes() =>
      banco.colecao(Colecoes.solicitacoes).map(_solicitacoes);

  Stream<List<SolicitacaoReagendamento>> solicitacoesDoPaciente(
    String pacienteId,
  ) => banco
      .colecao(Colecoes.solicitacoes, campo: 'pacienteId', igualA: pacienteId)
      .map(_solicitacoes);

  Stream<SolicitacaoReagendamento?> solicitacao(String id) => banco
      .documento(Colecoes.solicitacoes, id)
      .map(
        (d) =>
            d == null ? null : SolicitacaoReagendamento.fromMap(d.id, d.dados),
      );

  Future<void> solicitarReagendamento({
    required Agendamento agendamento,
    required String responsavelNome,
    required DateTime novoHorario,
    required String motivo,
  }) {
    final id = banco.novoId(Colecoes.solicitacoes);
    final protocolo =
        'RG-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    return banco.gravar(
      Colecoes.solicitacoes,
      id,
      SolicitacaoReagendamento(
        id: id,
        agendamentoId: agendamento.id,
        pacienteId: agendamento.pacienteId,
        pacienteNome: agendamento.pacienteNome,
        responsavelNome: responsavelNome,
        profissionalId: agendamento.profissionalId,
        profissionalNome: agendamento.profissionalNome,
        sala: agendamento.sala,
        horarioAtual: agendamento.inicio,
        horarioPretendido: novoHorario,
        criadoEm: DateTime.now(),
        motivo: motivo,
        protocolo: protocolo,
      ).toMap(),
    );
  }

  // move o agendamento e fecha a solicitação no mesmo batch
  Future<void> aprovarSolicitacao(
    SolicitacaoReagendamento s, {
    required DateTime novoInicio,
    required Duration duracao,
    required String por,
  }) => banco.lote([
    Atualizar(Colecoes.agendamentos, s.agendamentoId, {
      'inicio': gravarData(novoInicio),
      'fim': gravarData(novoInicio.add(duracao)),
      'status': StatusAgendamento.confirmado.name,
    }),
    Atualizar(Colecoes.solicitacoes, s.id, {
      'status': StatusSolicitacao.aprovada.name,
      'resolvidoPor': por,
      'resolvidoEm': gravarData(DateTime.now()),
      'horarioFinal': gravarData(novoInicio),
    }),
  ]);

  Future<void> recusarSolicitacao(String id, {required String por}) =>
      banco.atualizar(Colecoes.solicitacoes, id, {
        'status': StatusSolicitacao.recusada.name,
        'resolvidoPor': por,
        'resolvidoEm': gravarData(DateTime.now()),
      });

  Stream<Evolucao?> evolucao(String agendamentoId) => banco
      .documento(Colecoes.evolucoes, agendamentoId)
      .map((d) => d == null ? null : Evolucao.fromMap(d.id, d.dados));

  Stream<List<Evolucao>> evolucoesDoPaciente(String pacienteId) => banco
      .colecao(Colecoes.evolucoes, campo: 'pacienteId', igualA: pacienteId)
      .map(
        (l) =>
            l.map((d) => Evolucao.fromMap(d.id, d.dados)).toList()
              ..sort((a, b) => b.data.compareTo(a.data)),
      );

  Future<void> salvarEvolucao(Evolucao e) =>
      banco.gravar(Colecoes.evolucoes, e.id, e.toMap());

  Future<void> finalizarEvolucao(Evolucao e) => banco.lote([
    Gravar(Colecoes.evolucoes, e.id, e.copyWith(finalizada: true).toMap()),
    Atualizar(Colecoes.agendamentos, e.id, {
      'status': StatusAgendamento.concluido.name,
      'evolucaoSalva': true,
    }),
  ]);

  Stream<List<Exercicio>> exerciciosDoPaciente(String pacienteId) => banco
      .colecao(Colecoes.exercicios, campo: 'pacienteId', igualA: pacienteId)
      .map(
        (l) =>
            l.map((d) => Exercicio.fromMap(d.id, d.dados)).toList()
              ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)),
      );

  Future<void> prescreverExercicio(Exercicio e) => banco.gravar(
    Colecoes.exercicios,
    banco.novoId(Colecoes.exercicios),
    e.toMap(),
  );

  // +1 na meta da semana e +1 estrela; bateu a meta, conclui
  Future<void> registrarPratica(Exercicio e) {
    final feitas = e.praticasSemana + 1;
    return banco.lote([
      Atualizar(Colecoes.exercicios, e.id, {
        'praticasSemana': feitas,
        'ultimaPratica': gravarData(DateTime.now()),
        if (feitas >= e.metaSemanal) 'status': StatusExercicio.concluido.name,
      }),
      Atualizar(Colecoes.pacientes, e.pacienteId, {
        'estrelas': const Incremento(1),
      }),
    ]);
  }

  static List<Cobranca> _cobrancas(List<Documento> l) =>
      l.map((d) => Cobranca.fromMap(d.id, d.dados)).toList()
        ..sort((a, b) => b.vencimento.compareTo(a.vencimento));

  Stream<List<Cobranca>> cobrancas() =>
      banco.colecao(Colecoes.cobrancas).map(_cobrancas);

  Stream<List<Cobranca>> cobrancasDoPaciente(String pacienteId) => banco
      .colecao(Colecoes.cobrancas, campo: 'pacienteId', igualA: pacienteId)
      .map(_cobrancas);

  Future<void> registrarPagamento(String id, FormaPagamento forma) =>
      banco.atualizar(Colecoes.cobrancas, id, {
        'pagoEm': gravarData(DateTime.now()),
        'forma': forma.name,
      });

  Future<void> marcarAvisoEnviado(String id) =>
      banco.atualizar(Colecoes.cobrancas, id, {'avisoEnviado': true});
}
