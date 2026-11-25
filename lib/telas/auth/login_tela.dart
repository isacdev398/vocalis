import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/tema.dart';
import '../../core/validacao.dart';
import '../../estado/sessao.dart';
import '../../rotas.dart';
import '../../servicos/auth_servico.dart';
import '../../widgets/comuns.dart';
import '../casca.dart';

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await context.read<Sessao>().entrar(_email.text, _senha.text);
    } on AuthErro catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final erroEmail = Validacao.email(_email.text);
    if (erroEmail != null) {
      setState(() => _erro = 'Digite seu e-mail acima para redefinir a senha.');
      return;
    }
    try {
      await context.read<Sessao>().redefinirSenha(_email.text);
      if (mounted) {
        avisar(context, 'Enviamos um link de redefinição para ${_email.text}.');
      }
    } on AuthErro catch (e) {
      setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoFono(tamanho: 64)),
                  const SizedBox(height: 16),
                  Text(
                    'Vocalis',
                    textAlign: TextAlign.center,
                    style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sistema da clínica de fonoaudiologia',
                    textAlign: TextAlign.center,
                    style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
                  ),
                  const SizedBox(height: 28),
                  Cartao(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Entrar', style: TemaApp.titulo(size: 20)),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('campo-email'),
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: Validacao.email,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('campo-senha'),
                            controller: _senha,
                            obscureText: _ocultar,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _ocultar
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                icon: Icon(
                                  _ocultar
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _ocultar = !_ocultar),
                              ),
                            ),
                            validator: Validacao.senha,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _esqueciSenha,
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                          if (_erro != null) ...[
                            Bloco(
                              cor: Cores.erroFundo,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Cores.erroTexto,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _erro!,
                                      style: TemaApp.corpo(
                                        color: Cores.erroTexto,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton.icon(
                            onPressed: _enviando ? null : _entrar,
                            icon: _enviando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('Entrar'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.go(Rotas.cadastro),
                            child: const Text('Não tem conta? Cadastre-se'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou',
                          style: TemaApp.corpo(color: Cores.textoSuave),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => context.go(Rotas.perfis),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Entrar na demonstração'),
                  ),
                  if (!sessao.firebaseConfigurado) ...[
                    const SizedBox(height: 16),
                    Bloco(
                      cor: Cores.alertaFundo,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Cores.alertaTexto,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Firebase ainda não configurado: os dados ficam '
                              'só neste navegador. Contas de teste: '
                              'ana@vocalis.demo, camila@vocalis.demo, '
                              'juliana@vocalis.demo ou kariny@vocalis.demo '
                              '(senha demo123).',
                              style: TemaApp.corpo(
                                size: 13,
                                color: Cores.alertaTexto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
