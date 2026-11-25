import '../modelos/agendamento.dart';
import '../modelos/cobranca.dart';
import '../modelos/conversao.dart';
import '../modelos/evolucao.dart';
import '../modelos/exercicio.dart';
import '../modelos/paciente.dart';
import '../modelos/solicitacao.dart';
import '../modelos/usuario.dart';
import 'banco_dados.dart';

/// Nomes das coleções no banco.
abstract final class Colecoes {
  static const usuarios = 'usuarios';
  static const pacientes = 'pacientes';
  static const agendamentos = 'agendamentos';
  static const solicitacoes = 'solicitacoes';
  static const evolucoes = 'evolucoes';
  static const exercicios = 'exercicios';
  static const cobrancas = 'cobrancas';
}

/// Único ponto de acesso aos dados da clínica.
///
/// Recebe o [BancoDados] por injeção de dependência: no app real é o
/// Firestore; na demonstração e nos testes, um banco em memória. As telas
/// nunca falam com o banco diretamente.
///
/// As consultas usam no máximo um filtro de igualdade e a ordenação é feita
/// em Dart, assim o projeto não precisa de índices compostos no Firebase.
class ClinicaRepositorio {
  ClinicaRepositorio(this.banco);

  final BancoDados banco;

  // ---------------------------------------------------------------- Usuários

  Stream<Usuario?> usuario(String uid) => banco
      .documento(Colecoes.usuarios, uid)
      .map((d) => d == null ? null : Usuario.fromMap(d.id, d.dados));

  Future<void> salvarUsuario(Usuario u) =>
      banco.gravar(Colecoes.usuarios, u.id, u.toMap());

  /// Colaboradores (todos menos clientes), ordenados: dono, fonos, recepção.
  Stream<List<Usuario>> equipe() => banco.colecao(Colecoes.usuarios).map((l) {
    final lista = l
        .map((d) => Usuario.fromMap(d.id, d.dados))
        .where((u) => u.perfil != Perfil.cliente)
        .toList();
    const ordem = [Perfil.dono, Perfil.fono, Perfil.recepcao];
    // Ordena pelo nome sem o título ("Dra. Ana" vem antes de "Dr. Marcos").
    String chave(Usuario u) => u.nome.replaceFirst(RegExp(r'^Dra?\.\s*'), '');
    lista.sort((a, b) {
      final c = ordem.indexOf(a.perfil).compareTo(ordem.indexOf(b.perfil));
      return c != 0 ? c : chave(a).compareTo(chave(b));
    });
    return lista;
  });

  /// Profissionais que atendem (aparecem nos filtros da agenda).
  Stream<List<Usuario>> profissionais() => equipe().map(
    (l) => l.where((u) => u.ehProfissionalClinico && !u.convidado).toList(),
  );

  Future<void> atualizarPermissoes(String uid, Permissoes p) =>
      banco.atualizar(Colecoes.usuarios, uid, {'permissoes': p.toMap()});

  /// Pré-cadastra um colaborador. Ele cria a senha ao se cadastrar
  /// com o mesmo e-mail (ver [vincularConvite]).
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

  /// Se existir convite para este e-mail, devolve-o e apaga o documento
  /// provisório (o definitivo é criado com o uid do Auth).
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

  // --------------------------------------------------------------- Pacientes

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

  // ------------------------------------------------------------ Agendamentos

  static List<Agendamento> _agendamentos(List<Documento> l) =>
      l.map((d) => Agendamento.fromMap(d.id, d.dados)).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  Stream<List<Agendamento>> agendamentos() =>
      banco.colecao(Colecoes.agendamentos).map(_agendamentos);

  /// Só os agendamentos com início em [de, ate). Usado pela agenda (semana
  /// visível) e pelo painel (mês atual e anterior) no lugar da coleção inteira.
  Stream<List<Agendamento>> agendamentosEntre(DateTime de, DateTime ate) =>
      banco
          .colecaoEntre(
            Colecoes.agendamentos,
            campo: 'inicio',
            de: de,
            ate: ate,
          )
          .map(_agendamentos);

  /// Quantas sessões o paciente já tem (leitura única, filtrada por paciente).
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

  // ------------------------------------------------------------ Solicitações

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

  /// Confirma a troca: move o agendamento e fecha a solicitação numa única
  /// operação atômica (lote), para os 4 portais verem a mesma coisa.
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

  // --------------------------------------------------------------- Evoluções

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

  /// Assina a evolução e encerra o atendimento.
  Future<void> finalizarEvolucao(Evolucao e) => banco.lote([
    Gravar(Colecoes.evolucoes, e.id, e.copyWith(finalizada: true).toMap()),
    Atualizar(Colecoes.agendamentos, e.id, {
      'status': StatusAgendamento.concluido.name,
      'evolucaoSalva': true,
    }),
  ]);

  // -------------------------------------------------------------- Exercícios

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

  /// Registra uma prática feita em casa: soma 1 na meta semanal e dá uma
  /// estrela ao paciente. Ao bater a meta o exercício é concluído.
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

  // --------------------------------------------------------------- Cobranças

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
