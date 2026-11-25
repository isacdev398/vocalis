import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../core/validacao.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/sessao.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/usuario.dart';
import '../../widgets/comuns.dart';

/// Dono — "Gestão de Equipe e Permissões" (Stitch).
class EquipeTela extends StatefulWidget {
  const EquipeTela({super.key});

  @override
  State<EquipeTela> createState() => _EquipeTelaState();
}

class _EquipeTelaState extends State<EquipeTela> {
  bool _verMatriz = false;
  String? _editandoId;
  Permissoes? _rascunho;
  final _scroll = GlobalKey();

  void _editar(Usuario u) {
    setState(() {
      _editandoId = u.id;
      _rascunho = u.permissoes;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _scroll.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    final eu = context.watch<Sessao>().usuario!;

    return Observar<(List<Usuario>, List<Agendamento>)>(
      chave: repo,
      stream: () => Rx.combineLatest2(
        repo.equipe(),
        repo.agendamentos(),
        (List<Usuario> u, List<Agendamento> a) => (u, a),
      ),
      builder: (context, dados) {
        final (equipe, agendamentos) = dados;
        final hoje = DateTime.now();
        final ativos = equipe.where((u) => !u.convidado).length;
        final editando = equipe.where((u) => u.id == _editandoId).firstOrNull;

        return Conteudo(
          children: [
            Cartao(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Cores.primaria,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Sobrelinha('Equipe', cor: Cores.primaria),
                      ),
                      IconButton.filled(
                        tooltip: 'Histórico de alterações',
                        style: IconButton.styleFrom(
                          backgroundColor: Cores.mentaSuave,
                          foregroundColor: Cores.primaria,
                        ),
                        onPressed: () =>
                            avisarSimulado(context, 'Histórico de alterações'),
                        icon: const Icon(Icons.manage_search),
                      ),
                    ],
                  ),
                  Text(
                    'Equipe e permissões',
                    style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quem faz parte da equipe e o que cada um pode ver.',
                    style: TemaApp.corpo(color: Cores.textoSuave),
                  ),
                  const SizedBox(height: 12),
                  Bloco(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        Text(
                          '$ativos colaboradores ativos',
                          style: TemaApp.corpo(weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _DialogoConvite(repo: repo),
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Convidar colaborador'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.groups_outlined),
                  label: Text('Colaboradores (${equipe.length})'),
                ),
                const ButtonSegment(
                  value: true,
                  icon: Icon(Icons.grid_view),
                  label: Text('Permissões por perfil'),
                ),
              ],
              selected: {_verMatriz},
              onSelectionChanged: (s) => setState(() => _verMatriz = s.first),
            ),
            const SizedBox(height: 16),
            if (_verMatriz)
              const _Matriz()
            else ...[
              const Sobrelinha('Profissionais cadastrados'),
              const SizedBox(height: 10),
              for (final u in equipe) ...[
                _CartaoColaborador(
                  usuario: u,
                  ehVoce: u.id == eu.id,
                  emEdicao: u.id == _editandoId,
                  atendimentosHoje: agendamentos
                      .where(
                        (a) =>
                            a.profissionalId == u.id &&
                            a.inicio.mesmoDia(hoje) &&
                            a.status.ativo,
                      )
                      .length,
                  onConfigurar: u.id == eu.id ? null : () => _editar(u),
                ),
                const SizedBox(height: 10),
              ],
              if (editando != null && _rascunho != null) ...[
                const SizedBox(height: 8),
                _AjusteAcessos(
                  key: _scroll,
                  usuario: editando,
                  rascunho: _rascunho!,
                  aoMudar: (p) => setState(() => _rascunho = p),
                  aoSalvar: () async {
                    await repo.atualizarPermissoes(editando.id, _rascunho!);
                    if (!context.mounted) return;
                    avisar(
                      context,
                      'Permissões de ${editando.nome} atualizadas. '
                      'O acesso muda na hora para o colaborador.',
                    );
                    setState(() => _editandoId = null);
                  },
                  aoCancelar: () => setState(() => _editandoId = null),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _CartaoColaborador extends StatelessWidget {
  const _CartaoColaborador({
    required this.usuario,
    required this.ehVoce,
    required this.emEdicao,
    required this.atendimentosHoje,
    required this.onConfigurar,
  });
  final Usuario usuario;
  final bool ehVoce;
  final bool emEdicao;
  final int atendimentosHoje;
  final VoidCallback? onConfigurar;

  @override
  Widget build(BuildContext context) {
    final u = usuario;
    final p = u.permissoes;
    final clinico = u.perfil == Perfil.fono;

    Widget chip(String texto, bool ok, {bool bloqueio = false}) => ok
        ? Pilula('$texto ✓', fundo: Cores.containerBaixo, cor: Cores.texto)
        : bloqueio
        ? Pilula.erro('$texto BLOQUEADO', icone: Icons.lock_outline)
        : Pilula(
            '$texto restrito',
            icone: Icons.block,
            fundo: Cores.containerBaixo,
          );

    return Cartao(
      faixa: emEdicao
          ? Cores.teal
          : u.convidado
          ? Cores.alerta
          : Cores.primaria,
      borda: emEdicao ? Cores.teal : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(u.nome, tamanho: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(u.nome, style: TemaApp.titulo(size: 18)),
                        if (u.cargo.isNotEmpty)
                          u.perfil == Perfil.recepcao
                              ? Pilula.lilas(u.cargo)
                              : Pilula.menta(u.cargo),
                        if (ehVoce) const Pilula('Você'),
                      ],
                    ),
                    Text(
                      [
                        if (u.registro.isNotEmpty) u.registro,
                        if (u.especialidade.isNotEmpty) u.especialidade,
                      ].join(' • '),
                      style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.convidado
                          ? 'Convite pendente (${u.email})'
                          : clinico
                          ? 'Ativa • $atendimentosHoje atendimentos hoje'
                          : 'Ativa',
                      style: TemaApp.corpo(
                        size: 12,
                        color: u.convidado
                            ? Cores.alertaTexto
                            : Cores.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              if (emEdicao) const Pilula.menta('Em Edição'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              chip('Agenda', p.agenda),
              if (p.cadastros) chip('Cadastros', true),
              if (p.cobranca) chip('Cobrança/PIX', true),
              if (p.financeiro) chip('Financeiro', true),
              if (clinico || u.temCrfa)
                chip('Prontuário/SOAP', p.clinico)
              else
                chip('Clínico', false, bloqueio: true),
              if (clinico && !p.financeiro) chip('Financeiro', false),
            ],
          ),
          if (onConfigurar != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onConfigurar,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Permissões'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AjusteAcessos extends StatelessWidget {
  const _AjusteAcessos({
    super.key,
    required this.usuario,
    required this.rascunho,
    required this.aoMudar,
    required this.aoSalvar,
    required this.aoCancelar,
  });
  final Usuario usuario;
  final Permissoes rascunho;
  final ValueChanged<Permissoes> aoMudar;
  final VoidCallback aoSalvar;
  final VoidCallback aoCancelar;

  @override
  Widget build(BuildContext context) {
    final r = rascunho;
    final semCrfa = !usuario.temCrfa;
    return Cartao(
      faixa: Cores.teal,
      elevado: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                color: Cores.primaria,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Sobrelinha('Permissões atuais', cor: Cores.primaria),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: aoCancelar,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Ajuste de Acessos: ${usuario.nome}',
            style: TemaApp.titulo(size: 22),
          ),
          Text(
            'Papel: ${usuario.perfil.rotulo}'
            '${usuario.cargo.isEmpty ? '' : ' / ${usuario.cargo}'}',
            style: TemaApp.corpo(color: Cores.textoSuave),
          ),
          const SizedBox(height: 14),
          _Permissao(
            numero: 1,
            icone: Icons.calendar_month_outlined,
            titulo: 'Agenda',
            texto: 'Criar, reagendar, cancelar e confirmar atendimentos da clínica.',
            valor: r.agenda,
            aoMudar: (v) => aoMudar(r.copyWith(agenda: v)),
          ),
          _Permissao(
            numero: 2,
            icone: Icons.contact_page_outlined,
            titulo: 'Cadastros de pacientes',
            texto:
                'Gerenciar fichas cadastrais, responsáveis legais e lembretes.',
            valor: r.cadastros,
            aoMudar: (v) => aoMudar(r.copyWith(cadastros: v)),
          ),
          _Permissao(
            numero: 3,
            icone: Icons.point_of_sale_outlined,
            titulo: 'Cobrança no balcão',
            texto: 'Registrar recebimento de sessões e mensalidades.',
            valor: r.cobranca,
            aoMudar: (v) => aoMudar(r.copyWith(cobranca: v)),
          ),
          _Permissao(
            numero: 4,
            icone: Icons.query_stats,
            titulo: 'Financeiro',
            texto: 'Visualizar faturamento, inadimplência e mix de pagamentos.',
            valor: r.financeiro,
            aoMudar: (v) => aoMudar(r.copyWith(financeiro: v)),
          ),
          _Permissao(
            numero: 5,
            icone: Icons.lock_outline,
            titulo: 'Prontuário e evoluções',
            texto:
                'Pode ler e escrever evoluções e ver as '
                'hipóteses diagnósticas.',
            valor: r.clinico && !semCrfa,
            etiqueta: const Pilula.erro('CFFa'),
            aoMudar: semCrfa ? null : (v) => aoMudar(r.copyWith(clinico: v)),
          ),
          Bloco(
            cor: Cores.erroFundo,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                  color: Cores.erroTexto,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Só quem tem CRFa pode ver dados clínicos (sigilo profissional).',
                    style: TemaApp.corpo(size: 12, color: Cores.erroTexto),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: r == usuario.permissoes ? null : aoSalvar,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar permissões'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Permissao extends StatelessWidget {
  const _Permissao({
    required this.numero,
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.valor,
    required this.aoMudar,
    this.etiqueta,
  });
  final int numero;
  final IconData icone;
  final String titulo;
  final String texto;
  final bool valor;
  final ValueChanged<bool>? aoMudar;
  final Widget? etiqueta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconeQuadrado(
          icone,
          tamanho: 36,
          fundo: aoMudar == null ? Cores.erroFundo : Cores.containerBaixo,
          cor: aoMudar == null ? Cores.erroForte : Cores.textoSuave,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$numero. $titulo',
                style: TemaApp.corpo(size: 15, weight: FontWeight.w700),
              ),
              if (etiqueta != null) ...[const SizedBox(height: 4), etiqueta!],
              const SizedBox(height: 2),
              Text(texto, style: TemaApp.corpo(color: Cores.textoSuave)),
            ],
          ),
        ),
        Switch(value: valor, onChanged: aoMudar),
      ],
    ),
  );
}

class _Matriz extends StatelessWidget {
  const _Matriz();

  @override
  Widget build(BuildContext context) {
    const perfis = [Perfil.recepcao, Perfil.fono, Perfil.dono];
    final linhas = <(String, bool Function(Permissoes))>[
      ('Agenda', (p) => p.agenda),
      ('Cadastros', (p) => p.cadastros),
      ('Cobrança', (p) => p.cobranca),
      ('Financeiro', (p) => p.financeiro),
      ('Clínico (SOAP)', (p) => p.clinico),
    ];
    return Cartao(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Sobrelinha('Permissão')),
                for (final p in perfis)
                  Expanded(
                    flex: 2,
                    child: Text(
                      p.rotulo.split(' ').first,
                      textAlign: TextAlign.center,
                      style: TemaApp.corpo(size: 12, weight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          for (final (nome, ler) in linhas)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(nome)),
                  for (final p in perfis)
                    Expanded(
                      flex: 2,
                      child: Icon(
                        ler(Permissoes.padrao(p))
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        size: 20,
                        color: ler(Permissoes.padrao(p))
                            ? Cores.primaria
                            : Cores.contornoSuave,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Valem para quem for cadastrado. Dá para mudar por pessoa.',
              style: TemaApp.corpo(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoConvite extends StatefulWidget {
  const _DialogoConvite({required this.repo});
  final ClinicaRepositorio repo;

  @override
  State<_DialogoConvite> createState() => _DialogoConviteState();
}

class _DialogoConviteState extends State<_DialogoConvite> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _registro = TextEditingController();
  final _especialidade = TextEditingController();
  Perfil _perfil = Perfil.fono;

  @override
  void dispose() {
    for (final c in [_nome, _email, _registro, _especialidade]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    await widget.repo.convidarColaborador(
      nome: _nome.text.trim(),
      email: _email.text.trim(),
      perfil: _perfil,
      cargo: _perfil == Perfil.fono ? 'Fonoaudiólogo(a)' : 'Recepção',
      registro: _perfil == Perfil.fono ? _registro.text.trim() : '',
      especialidade: _especialidade.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    avisar(
      context,
      'Convite registrado. ${Formatos.primeiroNome(_nome.text)} recebe o '
      'perfil ao se cadastrar com ${_email.text.trim()}.',
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Convidar colaborador'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<Perfil>(
              segments: const [
                ButtonSegment(value: Perfil.fono, label: Text('Fono')),
                ButtonSegment(value: Perfil.recepcao, label: Text('Recepção')),
              ],
              selected: {_perfil},
              onSelectionChanged: (s) => setState(() => _perfil = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: Validacao.nomeCompleto,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: Validacao.email,
            ),
            if (_perfil == Perfil.fono) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _registro,
                decoration: const InputDecoration(
                  labelText: 'CRFa',
                  hintText: 'CRFa 2-12345',
                ),
                validator: Validacao.crfa,
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _especialidade,
              decoration: const InputDecoration(
                labelText: 'Especialidade / função (opcional)',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _enviar, child: const Text('Registrar convite')),
    ],
  );
}
