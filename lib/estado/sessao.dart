import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/perf.dart';
import '../dados/banco_dados.dart';
import '../dados/clinica_repositorio.dart';
import '../dados/dados_demo.dart';
import '../modelos/paciente.dart';
import '../modelos/usuario.dart';
import '../servicos/auth_servico.dart';

/// Um "lugar" onde os dados moram: autenticação + banco.
class Backend {
  Backend({required this.auth, required this.repo, required this.local});

  final AuthServico auth;
  final ClinicaRepositorio repo;

  /// true = memória do navegador (demonstração); false = Firebase real.
  final bool local;

  /// Cria um backend local já com o cenário da demonstração.
  static Future<Backend> demonstracao({
    DateTime? agora,
    int estresse = Perf.estresse,
  }) async {
    final banco = MemoriaBanco();
    await popularDadosDemo(banco, agora: agora, estresse: estresse);
    final auth = LocalAuthServico();
    for (final u in ContasDemo.usuarios) {
      auth.registrarConta(u.email, ContasDemo.senha, u.id);
    }
    return Backend(auth: auth, repo: ClinicaRepositorio(banco), local: true);
  }
}

enum EstadoSessao { carregando, deslogado, logado }

/// Estado global de autenticação, compartilhado pelo Provider.
///
/// Guarda quem está logado e qual backend está ativo. O roteador escuta esta
/// classe (refreshListenable) para redirecionar entre login e portais.
class Sessao extends ChangeNotifier {
  Sessao({Backend? firebase, Future<Backend> Function()? criarDemo})
    : _firebase = firebase, // ignore: prefer_initializing_formals
      _criarDemo = criarDemo ?? Backend.demonstracao;

  final Backend? _firebase;
  final Future<Backend> Function() _criarDemo;
  Backend? _demo;
  Backend? _ativo;

  StreamSubscription<String?>? _subAuth;
  StreamSubscription<Usuario?>? _subUsuario;

  EstadoSessao _estado = EstadoSessao.carregando;
  Usuario? _usuario;
  String? _uid;

  EstadoSessao get estado => _estado;
  Usuario? get usuario => _usuario;
  bool get firebaseConfigurado => _firebase != null;

  /// Está navegando pela demonstração (dados fictícios em memória).
  bool get emDemonstracao => _ativo?.local ?? true;

  ClinicaRepositorio get repo => _ativo!.repo;

  /// Liga a sessão no backend principal (Firebase, ou local se não houver).
  Future<void> iniciar() async {
    if (_firebase != null) {
      _usar(_firebase);
    } else {
      _usar(await _obterDemo());
    }
  }

  Future<Backend> _obterDemo() async => _demo ??= await _criarDemo();

  void _usar(Backend b) {
    if (identical(b, _ativo)) return;
    _subAuth?.cancel();
    _subUsuario?.cancel();
    _ativo = b;
    _estado = EstadoSessao.carregando;
    _subAuth = b.auth.mudancas.listen(_aoMudarAuth);
  }

  void _aoMudarAuth(String? uid) {
    if (uid == _uid && _estado != EstadoSessao.carregando) return;
    _uid = uid;
    _subUsuario?.cancel();
    if (uid == null) {
      _usuario = null;
      _estado = EstadoSessao.deslogado;
      notifyListeners();
      return;
    }
    _estado = EstadoSessao.carregando;
    notifyListeners();
    _subUsuario = _ativo!.repo.usuario(uid).listen((u) {
      // O documento pode demorar um instante para existir logo após o cadastro.
      if (u == null) return;
      _usuario = u;
      _estado = EstadoSessao.logado;
      notifyListeners();
    });
  }

  Future<void> entrar(String email, String senha) async {
    if (_firebase != null) _usar(_firebase);
    await _ativo!.auth.entrar(email, senha);
  }

  Future<void> redefinirSenha(String email) =>
      _ativo!.auth.redefinirSenha(email);

  /// Cria a conta no Auth e o documento do usuário no banco.
  /// Para clientes, também cria a ficha do paciente acompanhado.
  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required Perfil perfil,
    String registro = '',
    String nomePaciente = '',
    DateTime? nascimentoPaciente,
    String parentesco = '',
  }) async {
    if (_firebase != null) _usar(_firebase);
    final b = _ativo!;
    final uid = await b.auth.cadastrar(email, senha);
    final convite = await b.repo.vincularConvite(email);

    String? pacienteId;
    final perfilFinal = convite?.perfil ?? perfil;
    if (perfilFinal == Perfil.cliente) {
      pacienteId = await b.repo.salvarPaciente(
        Paciente(
          id: '',
          nome: nomePaciente.trim(),
          dataNascimento: nascimentoPaciente ?? DateTime(2018),
          responsavelNome: nome.trim(),
          parentesco: parentesco,
        ),
      );
    }

    await b.repo.salvarUsuario(
      Usuario(
        id: uid,
        nome: nome.trim(),
        email: email.trim().toLowerCase(),
        perfil: perfilFinal,
        cargo: convite?.cargo ?? '',
        registro: convite?.registro ?? registro.trim(),
        especialidade: convite?.especialidade ?? '',
        pacienteId: pacienteId,
        parentesco: parentesco,
        permissoes: convite?.permissoes ?? Permissoes.padrao(perfilFinal),
      ),
    );
  }

  /// Repositório da demonstração (o Seletor de Perfis mostra dados ao vivo).
  Future<ClinicaRepositorio> repoDemonstracao() async =>
      (await _obterDemo()).repo;

  /// Seletor de Perfis: entra na demonstração como um dos personagens.
  /// Completa quando o perfil já foi carregado.
  Future<Usuario> entrarNaDemonstracao(String uid) async {
    final demo = await _obterDemo();
    _usar(demo);
    (demo.auth as LocalAuthServico).entrarComo(uid);
    return _aguardarUsuario(uid);
  }

  Future<Usuario> _aguardarUsuario(String uid) {
    bool pronto() => _estado == EstadoSessao.logado && _usuario?.id == uid;
    if (pronto()) return Future.value(_usuario);
    final c = Completer<Usuario>();
    void ouvir() {
      if (pronto()) {
        removeListener(ouvir);
        c.complete(_usuario);
      }
    }

    addListener(ouvir);
    return c.future;
  }

  Future<void> sair() async {
    await _ativo?.auth.sair();
    if (_firebase != null && !identical(_ativo, _firebase)) {
      _usar(_firebase);
    }
  }

  /// No Firebase real, grava o cenário de exemplo para apresentar o app.
  Future<void> popularDadosDeExemplo() => popularDadosDemo(repo.banco);

  @override
  void dispose() {
    _subAuth?.cancel();
    _subUsuario?.cancel();
    super.dispose();
  }
}
