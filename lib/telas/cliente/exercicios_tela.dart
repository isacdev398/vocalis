import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/sessao.dart';
import '../../modelos/exercicio.dart';
import '../../modelos/paciente.dart';
import '../../servicos/fala.dart';
import '../../widgets/comuns.dart';

class ExerciciosTela extends StatefulWidget {
  const ExerciciosTela({super.key});

  @override
  State<ExerciciosTela> createState() => _ExerciciosTelaState();
}

class _ExerciciosTelaState extends State<ExerciciosTela> {
  bool _verConcluidos = false;
  String? _selecionadoId;

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sessao>().usuario!;
    final repo = context.watch<ClinicaRepositorio>();
    final pid = usuario.pacienteId ?? '';

    return Observar<(Paciente?, List<Exercicio>)>(
      chave: (repo, pid),
      stream: () => Rx.combineLatest2(
        repo.paciente(pid),
        repo.exerciciosDoPaciente(pid),
        (Paciente? p, List<Exercicio> e) => (p, e),
      ),
      builder: (context, dados) {
        final (paciente, exercicios) = dados;
        if (paciente == null) {
          return const EstadoVazio(
            icone: Icons.child_care,
            titulo: 'Nenhum paciente vinculado',
          );
        }
        final aFazer = exercicios.where((e) => !e.concluido).toList();
        final feitos = exercicios.where((e) => e.concluido).toList();
        final atual =
            aFazer.where((e) => e.id == _selecionadoId).firstOrNull ??
            aFazer.firstOrNull;
        final outros = aFazer.where((e) => e.id != atual?.id).toList();

        return Conteudo(
          children: [
            Row(
              children: [
                const IconeQuadrado(
                  Icons.record_voice_over,
                  fundo: Cores.menta,
                  tamanho: 32,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Sobrelinha(
                    'Exercícios da semana',
                    cor: Cores.primaria,
                  ),
                ),
                Pilula.lilas(
                  '${paciente.estrelas} Estrelas',
                  icone: Icons.star_rounded,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Exercícios',
              style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
            ),
            Text(
              'Atividades personalizadas para ${paciente.nome}',
              style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
            ),
            const SizedBox(height: 16),
            _Abas(
              aFazer: aFazer.length,
              feitos: feitos.length,
              verConcluidos: _verConcluidos,
              onChanged: (v) => setState(() => _verConcluidos = v),
            ),
            const SizedBox(height: 16),
            if (_verConcluidos) ...[
              if (feitos.isEmpty)
                const EstadoVazio(
                  icone: Icons.emoji_events_outlined,
                  titulo: 'Nenhum exercício concluído ainda',
                ),
              for (final e in feitos) ...[
                _ItemConcluido(exercicio: e),
                const SizedBox(height: 10),
              ],
            ] else if (atual == null)
              const EstadoVazio(
                icone: Icons.celebration_outlined,
                titulo: 'Tudo feito por aqui!',
                texto:
                    'A fono vai prescrever novas atividades na próxima sessão.',
              )
            else ...[
              _PraticaAtual(
                key: ValueKey(atual.id),
                exercicio: atual,
                paciente: paciente,
              ),
              const SizedBox(height: 16),
              if (atual.ultimaPratica != null) ...[
                Cartao(
                  child: Row(
                    children: [
                      const IconeQuadrado(
                        Icons.workspace_premium_outlined,
                        fundo: Cores.secundariaContainer,
                        cor: Cores.ardosia,
                        tamanho: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Sobrelinha('Sessão anterior'),
                            Text(
                              'Prática registrada ${_quando(atual.ultimaPratica!)}',
                              style: TemaApp.corpo(size: 15),
                            ),
                          ],
                        ),
                      ),
                      const Pilula.alerta('+1 estrela ganha!'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final (i, e) in outros.indexed) ...[
                Cartao(
                  onTap: () => setState(() => _selecionadoId = e.id),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Cores.container,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${i + 2}',
                          style: TemaApp.titulo(size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.titulo, style: TemaApp.titulo(size: 15)),
                            Text(
                              'Duração sugerida: ${e.duracaoMin} minutos',
                              style: TemaApp.corpo(
                                size: 13,
                                color: Cores.textoSuave,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CircleAvatar(
                        backgroundColor: Cores.container,
                        child: Icon(Icons.chevron_right, color: Cores.texto),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (atual.orientacaoPais.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Cores.container,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            color: Cores.primaria,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Sobrelinha(
                            'Dica da fono para a família',
                            cor: Cores.primaria,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Faça como uma brincadeira.',
                        style: TemaApp.titulo(size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        atual.orientacaoPais,
                        style: TemaApp.corpo(size: 15, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.help_outline, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Elogie o esforço, sem cobrar demais',
                            style: TemaApp.corpo(size: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  String _quando(DateTime d) {
    final hoje = DateTime.now();
    if (d.mesmoDia(hoje)) return 'hoje às ${Formatos.hora(d)}';
    if (d.mesmoDia(hoje.subtract(const Duration(days: 1)))) {
      return 'ontem às ${Formatos.hora(d)}';
    }
    return 'em ${Formatos.diaMes(d)} às ${Formatos.hora(d)}';
  }
}

class _Abas extends StatelessWidget {
  const _Abas({
    required this.aFazer,
    required this.feitos,
    required this.verConcluidos,
    required this.onChanged,
  });
  final int aFazer;
  final int feitos;
  final bool verConcluidos;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget aba(String texto, IconData icone, bool ativa, bool valor) =>
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(valor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 44,
              decoration: BoxDecoration(
                color: ativa ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: ativa ? Sombras.nivel1 : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icone,
                    size: 18,
                    color: ativa ? Cores.primaria : Cores.textoSuave,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    texto,
                    style: TemaApp.corpo(
                      size: 15,
                      weight: FontWeight.w600,
                      color: ativa ? Cores.primaria : Cores.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Cores.container,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          aba(
            'Para fazer ($aFazer)',
            Icons.check_circle_outline,
            !verConcluidos,
            false,
          ),
          aba(
            'Concluídos ($feitos)',
            Icons.assignment_turned_in_outlined,
            verConcluidos,
            true,
          ),
        ],
      ),
    );
  }
}

enum _Gravacao { pronto, gravando, analisado }

class _PraticaAtual extends StatefulWidget {
  const _PraticaAtual({
    super.key,
    required this.exercicio,
    required this.paciente,
  });
  final Exercicio exercicio;
  final Paciente paciente;

  @override
  State<_PraticaAtual> createState() => _PraticaAtualState();
}

class _PraticaAtualState extends State<_PraticaAtual> {
  int _indice = 0;
  bool _tocando = false;
  _Gravacao _gravacao = _Gravacao.pronto;
  bool _registrando = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Estimulo? get _estimulo => widget.exercicio.estimulos.isEmpty
      ? null
      : widget.exercicio.estimulos[_indice % widget.exercicio.estimulos.length];

  Future<void> _ouvir() async {
    final palavra = _estimulo?.palavra ?? widget.exercicio.titulo;
    setState(() => _tocando = true);
    final falou = await falar(palavra);
    if (!falou && mounted) {
      avisarSimulado(context, 'Áudio de referência');
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _tocando = false);
    });
  }

  void _gravar() {
    setState(() => _gravacao = _Gravacao.gravando);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _gravacao = _Gravacao.analisado);
    });
  }

  Future<void> _concluir() async {
    setState(() => _registrando = true);
    await context.read<ClinicaRepositorio>().registrarPratica(widget.exercicio);
    if (!mounted) return;
    setState(() {
      _registrando = false;
      _gravacao = _Gravacao.pronto;
      _indice++;
    });
    final faltam =
        widget.exercicio.metaSemanal - widget.exercicio.praticasSemana - 1;
    avisar(
      context,
      faltam <= 0
          ? '🎉 Meta da semana concluída! +1 estrela para ${widget.paciente.primeiroNome}.'
          : '⭐ Prática registrada! Faltam $faltam para a meta da semana.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercicio;
    final est = _estimulo;
    final nome = widget.paciente.primeiroNome;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(top: BorderSide(color: Cores.primaria, width: 6)),
        boxShadow: Sombras.nivel2,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.categoria.isNotEmpty) Pilula.menta(e.categoria),
                    const SizedBox(height: 6),
                    Text(e.titulo, style: TemaApp.titulo(size: 22)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Ouvir palavra',
                style: IconButton.styleFrom(
                  backgroundColor: Cores.secundariaContainer,
                ),
                onPressed: _ouvir,
                icon: const Icon(Icons.hearing),
              ),
            ],
          ),
          if (e.instrucao.isNotEmpty) ...[
            const SizedBox(height: 12),
            Bloco(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Como fazer: ',
                            style: TemaApp.corpo(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: e.instrucao,
                            style: TemaApp.corpo(size: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (est != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFE9F8F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Cores.borda),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Palavra anterior',
                    onPressed: () => setState(() {
                      _indice = (_indice - 1) % e.estimulos.length;
                      _gravacao = _Gravacao.pronto;
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: Sombras.nivel2,
                          ),
                          child: Text(
                            est.emoji,
                            style: const TextStyle(fontSize: 56),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ouça e repita com calma',
                          style: TemaApp.corpo(size: 13),
                        ),
                        Text(
                          est.palavra,
                          style: TemaApp.titulo(
                            size: 36,
                            color: Cores.primaria,
                          ),
                        ),
                        Pilula('transcrição: [${est.silabas}]'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < e.estimulos.length; i++)
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _indice % e.estimulos.length
                                      ? Cores.primaria
                                      : Cores.contornoSuave,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próxima palavra',
                    onPressed: () => setState(() {
                      _indice++;
                      _gravacao = _Gravacao.pronto;
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Bloco(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Sobrelinha('Áudio de referência')),
                    Text(
                      e.prescritoPorNome,
                      style: TemaApp.corpo(
                        size: 12,
                        color: Cores.primaria,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _ouvir,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _tocando
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            color: Cores.primaria,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ouvir exemplo "${est?.palavra ?? e.titulo}"',
                              style: TemaApp.corpo(weight: FontWeight.w600),
                            ),
                          ),
                          OndaSonora(ativa: _tocando),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Bloco(
            cor: Cores.container,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Sobrelinha('Gravação da $nome')),
                    Text(
                      switch (_gravacao) {
                        _Gravacao.pronto => 'Pronto para gravar',
                        _Gravacao.gravando => 'Gravando…',
                        _Gravacao.analisado => 'Gravação concluída',
                      },
                      style: TemaApp.corpo(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _gravacao == _Gravacao.gravando
                            ? Cores.erroForte
                            : Cores.primaria,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _gravacao == _Gravacao.gravando ? null : _gravar,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Cores.erroFundo,
                            child: Icon(
                              _gravacao == _Gravacao.gravando
                                  ? Icons.stop
                                  : Icons.mic,
                              color: Cores.erroForte,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _gravacao == _Gravacao.gravando
                                  ? 'Ouvindo a $nome…'
                                  : 'Gravar repetição da $nome',
                              style: TemaApp.titulo(
                                size: 17,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_gravacao == _Gravacao.gravando)
                            const OndaSonora(ativa: true, cor: Cores.erroForte),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_gravacao == _Gravacao.analisado) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Cores.menta,
                          child: Icon(Icons.verified, color: Cores.primaria),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ótima tentativa!',
                                style: TemaApp.corpo(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: Cores.primaria,
                                ),
                              ),
                              Text(
                                'Análise acústica simulada nesta versão. A fono '
                                'avalia a gravação real na próxima sessão.',
                                style: TemaApp.corpo(size: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _registrando ? null : _concluir,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Registrar prática',
                style: TemaApp.titulo(
                  size: 18,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemConcluido extends StatelessWidget {
  const _ItemConcluido({required this.exercicio});
  final Exercicio exercicio;

  @override
  Widget build(BuildContext context) => Cartao(
    faixa: Cores.sucesso,
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: Cores.sucesso),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercicio.titulo, style: TemaApp.titulo(size: 15)),
              Text(
                '${exercicio.praticasSemana} de ${exercicio.metaSemanal} práticas'
                '${exercicio.ultimaPratica == null ? '' : ' • última em ${Formatos.diaMes(exercicio.ultimaPratica!)}'}',
                style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
              ),
            ],
          ),
        ),
        const Pilula.sucesso('Concluído'),
      ],
    ),
  );
}

class OndaSonora extends StatefulWidget {
  const OndaSonora({super.key, required this.ativa, this.cor = Cores.primaria});
  final bool ativa;
  final Color cor;

  @override
  State<OndaSonora> createState() => _OndaSonoraState();
}

class _OndaSonoraState extends State<OndaSonora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ativa) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant OndaSonora old) {
    super.didUpdateWidget(old);
    if (widget.ativa && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.ativa) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const alturas = [8.0, 16, 22, 12, 18, 10];
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, h) in alturas.indexed)
            Container(
              width: 3,
              height: widget.ativa
                  ? 4 + h * (0.4 + 0.6 * ((_c.value + i * 0.17) % 1))
                  : h.toDouble(),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.cor.withValues(alpha: widget.ativa ? 1 : 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
