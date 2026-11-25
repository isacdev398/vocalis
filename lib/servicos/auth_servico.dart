import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Erro de autenticação já traduzido para exibir ao usuário.
class AuthErro implements Exception {
  const AuthErro(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Contrato de autenticação. As telas e o estado dependem só desta interface,
/// então dá para trocar Firebase por uma versão local (demo/testes).
abstract class AuthServico {
  /// Emite o uid do usuário logado, ou null quando sai.
  Stream<String?> get mudancas;
  String? get uidAtual;

  Future<String> entrar(String email, String senha);
  Future<String> cadastrar(String email, String senha);
  Future<void> redefinirSenha(String email);
  Future<void> sair();
}

/// Implementação real com Firebase Authentication.
class FirebaseAuthServico implements AuthServico {
  FirebaseAuthServico([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<String?> get mudancas => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get uidAtual => _auth.currentUser?.uid;

  @override
  Future<String> entrar(String email, String senha) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthErro(traduzirErro(e.code));
    }
  }

  @override
  Future<String> cadastrar(String email, String senha) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthErro(traduzirErro(e.code));
    }
  }

  @override
  Future<void> redefinirSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthErro(traduzirErro(e.code));
    }
  }

  @override
  Future<void> sair() => _auth.signOut();

  static String traduzirErro(String codigo) => switch (codigo) {
    'invalid-email' => 'E-mail inválido.',
    'user-disabled' => 'Esta conta foi desativada.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'E-mail ou senha incorretos.',
    'email-already-in-use' => 'Já existe uma conta com este e-mail.',
    'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
    'too-many-requests' => 'Muitas tentativas. Aguarde um pouco.',
    'network-request-failed' => 'Sem conexão com a internet.',
    _ => 'Não foi possível concluir ($codigo).',
  };
}

/// Autenticação em memória, usada no modo demonstração e nos testes.
/// Valida e-mail e senha de verdade, mas nada sai do navegador.
class LocalAuthServico implements AuthServico {
  final _contas = <String, ({String uid, String senha})>{};
  final _controller = StreamController<String?>.broadcast();
  String? _uid;
  int _proximo = 1;

  @override
  Stream<String?> get mudancas async* {
    yield _uid;
    yield* _controller.stream;
  }

  @override
  String? get uidAtual => _uid;

  /// Registra uma conta já existente (contas da demonstração).
  void registrarConta(String email, String senha, String uid) {
    _contas[email.trim().toLowerCase()] = (uid: uid, senha: senha);
  }

  /// Entra direto como um usuário (Seletor de Perfis).
  void entrarComo(String uid) {
    _uid = uid;
    _controller.add(uid);
  }

  @override
  Future<String> entrar(String email, String senha) async {
    final conta = _contas[email.trim().toLowerCase()];
    if (conta == null || conta.senha != senha) {
      throw const AuthErro('E-mail ou senha incorretos.');
    }
    entrarComo(conta.uid);
    return conta.uid;
  }

  @override
  Future<String> cadastrar(String email, String senha) async {
    final chave = email.trim().toLowerCase();
    if (_contas.containsKey(chave)) {
      throw const AuthErro('Já existe uma conta com este e-mail.');
    }
    if (senha.length < 6) {
      throw const AuthErro('A senha precisa ter pelo menos 6 caracteres.');
    }
    final uid = 'local-${_proximo++}';
    _contas[chave] = (uid: uid, senha: senha);
    entrarComo(uid);
    return uid;
  }

  @override
  Future<void> redefinirSenha(String email) async {
    if (!_contas.containsKey(email.trim().toLowerCase())) {
      throw const AuthErro('Nenhuma conta com este e-mail.');
    }
  }

  @override
  Future<void> sair() async {
    _uid = null;
    _controller.add(null);
  }
}
