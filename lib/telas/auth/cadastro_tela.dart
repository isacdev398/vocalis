import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../core/validacao.dart';
import '../../estado/sessao.dart';
import '../../modelos/usuario.dart';
import '../../rotas.dart';
import '../../servicos/auth_servico.dart';
import '../../widgets/comuns.dart';

class CadastroTela extends StatefulWidget {
  const CadastroTela({super.key});

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends State<CadastroTela> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _registro = TextEditingController();
  final _paciente = TextEditingController();
  Perfil _perfil = Perfil.cliente;
  String _parentesco = 'Mãe';
  DateTime? _nascimento;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_nome, _email, _senha, _registro, _paciente]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherNascimento() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 6),
      firstDate: DateTime(1920),
      lastDate: hoje,
      helpText: 'Data de nascimento do paciente',
    );
    if (d != null) setState(() => _nascimento = d);
  }

  Future<void> _cadastrar() async {
    if (!_form.currentState!.validate()) return;
    if (_perfil == Perfil.cliente && _nascimento == null) {
      setState(() => _erro = 'Informe a data de nascimento do paciente.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await context.read<Sessao>().cadastrar(
        nome: _nome.text,
        email: _email.text,
        senha: _senha.text,
        perfil: _perfil,
        registro: _registro.text,
        nomePaciente: _paciente.text,
        nascimentoPaciente: _nascimento,
        parentesco: _perfil == Perfil.cliente ? _parentesco : '',
      );
    } on AuthErro catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Rotas.entrar),
        ),
        title: const Text('Criar conta'),
      ),
      body: Form(
        key: _form,
        child: Conteudo(
          children: [
            Text(
              'Quem vai usar o app?',
              style: TemaApp.titulo(size: 18, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in Perfil.values)
                  ChoiceChip(
                    avatar: Icon(p.icone, size: 18),
                    label: Text(p.rotulo),
                    selected: _perfil == p,
                    onSelected: (_) => setState(() => _perfil = p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Colaboradores convidados pelo dono recebem o perfil do convite '
              'automaticamente ao se cadastrar com o mesmo e-mail.',
              style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _perfil == Perfil.cliente
                    ? 'Seu nome (responsável)'
                    : 'Nome completo',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: Validacao.nomeCompleto,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: Validacao.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senha,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha (mínimo 6 caracteres)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: Validacao.senha,
            ),
            if (_perfil == Perfil.fono) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _registro,
                decoration: const InputDecoration(
                  labelText: 'Registro profissional',
                  hintText: 'CRFa 2-12345',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: Validacao.crfa,
              ),
            ],
            if (_perfil == Perfil.cliente) ...[
              const SizedBox(height: 24),
              Text(
                'Paciente acompanhado',
                style: TemaApp.titulo(size: 18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paciente,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do paciente',
                  prefixIcon: Icon(Icons.child_care),
                ),
                validator: Validacao.nomeCompleto,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _escolherNascimento,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        _nascimento == null
                            ? 'Data de nascimento'
                            : Formatos.data(_nascimento!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _parentesco,
                      decoration: const InputDecoration(
                        labelText: 'Parentesco',
                      ),
                      items: [
                        for (final p in const [
                          'Mãe',
                          'Pai',
                          'Responsável',
                          'Próprio paciente',
                        ])
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) => setState(() => _parentesco = v!),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (_erro != null) ...[
              Bloco(
                cor: Cores.erroFundo,
                child: Text(
                  _erro!,
                  style: TemaApp.corpo(
                    color: Cores.erroTexto,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _enviando ? null : _cadastrar,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_enviando ? 'Criando conta…' : 'Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
