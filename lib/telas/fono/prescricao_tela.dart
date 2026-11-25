import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../core/validacao.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/sessao.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/exercicio.dart';
import '../../modelos/paciente.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';

class _Dados {
  _Dados(this.agendamento, this.paciente, this.exercicios);
  final Agendamento? agendamento;
  final Paciente? paciente;
  final List<Exercicio> exercicios;
}

/// Fono — "Prescrição de Exercícios" (Stitch).
class PrescricaoTela extends StatelessWidget {
  const PrescricaoTela({super.key, required this.agendamentoId});
  final String agendamentoId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    return Observar<_Dados>(
      chave: (repo, agendamentoId),
      stream: () => repo.agendamento(agendamentoId).switchMap((a) {
        if (a == null) return Stream.value(_Dados(null, null, const []));
        return Rx.combineLatest2(
          repo.paciente(a.pacienteId),
          repo.exerciciosDoPaciente(a.pacienteId),
          (Paciente? p, List<Exercicio> e) => _Dados(a, p, e),
        );
      }),
      builder: (context, d) {
        if (d.agendamento == null || d.paciente == null) {
          return const EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Atendimento não encontrado',
          );
        }
        return _Formulario(dados: d);
      },
    );
  }
}

class _Formulario extends StatefulWidget {
  const _Formulario({required this.dados});
  final _Dados dados;

  @override
  State<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends State<_Formulario> {
  static const _objetivos = [
    'Fonologia e Articulação (Fonemas)',
    'Linguagem Expressiva',
    'Fluência',
    'Voz',
    'Motricidade Orofacial',
    'Percepção Auditiva',
    'Sopro e Respiração',
  ];
  static const _frequencias = ['1x ao dia', '2x ao dia', '3x por semana'];
  static const _duracoes = [3, 5, 10, 15];

  /// Emojis lúdicos para palavras comuns nos treinos.
  static const _emojis = {
    'sapato': '👟',
    'sapo': '🐸',
    'sola': '🦶',
    'sino': '🔔',
    'sol': '☀️',
    'sorvete': '🍦',
    'sopa': '🍲',
    'casa': '🏠',
    'pato': '🦆',
    'bola': '⚽',
    'gato': '🐱',
    'rato': '🐭',
    'lua': '🌙',
    'peixe': '🐟',
    'zebra': '🦓',
    'chave': '🔑',
    'bolha': '🫧',
    'flor': '🌸',
  };

  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController(text: 'Palavras com o som /s/');
  final _descricao = TextEditingController(
    text: 'Posição inicial e medial • Repetição guiada',
  );
  final _instrucao = TextEditingController();
  late final _orientacao = TextEditingController(
    text:
        'Ajude ${_pac.primeiroNome} a manter a ponta da língua suave atrás dos '
        'dentes sem projetar para fora. Transforme a prática em brincadeira! '
        'Não corrija imediatamente; apenas repita com um sorriso.',
  );
  final _novaPalavra = TextEditingController();
  String _objetivo = _objetivos.first;
  String _frequencia = _frequencias.first;
  int _duracao = 10;
  int _fase = 1;
  int _meta = 4;
  final _estimulos = <Estimulo>[
    const Estimulo('sapato', '👟'),
    const Estimulo('sapo', '🐸'),
    const Estimulo('sola', '🦶'),
    const Estimulo('sino', '🔔'),
  ];
  bool _enviando = false;

  Paciente get _pac => widget.dados.paciente!;
  Agendamento get _ag => widget.dados.agendamento!;

  @override
  void dispose() {
    for (final c in [
      _titulo,
      _descricao,
      _instrucao,
      _orientacao,
      _novaPalavra,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _adicionarPalavra() {
    final p = _novaPalavra.text.trim().toLowerCase();
    if (p.isEmpty || _estimulos.any((e) => e.palavra == p)) return;
    setState(() => _estimulos.add(Estimulo(p, _emojis[p] ?? '🗣️')));
    _novaPalavra.clear();
  }

  Future<void> _atribuir() async {
    if (!_form.currentState!.validate()) return;
    if (_estimulos.isEmpty) {
      avisar(context, 'Adicione ao menos uma palavra-estímulo.');
      return;
    }
    final u = context.read<Sessao>().usuario!;
    setState(() => _enviando = true);
    await context.read<ClinicaRepositorio>().prescreverExercicio(
      Exercicio(
        id: '',
        pacienteId: _pac.id,
        titulo: _titulo.text.trim(),
        criadoEm: DateTime.now(),
        objetivo: _objetivo,
        categoria: _objetivo.split(' (').first,
        descricao: _descricao.text.trim(),
        instrucao: _instrucao.text.trim().isEmpty
            ? _orientacao.text.trim().split('.').first
            : _instrucao.text.trim(),
        orientacaoPais: _orientacao.text.trim(),
        estimulos: List.of(_estimulos),
        frequencia: _frequencia,
        duracaoMin: _duracao,
        fase: _fase,
        metaSemanal: _meta,
        prescritoPorId: u.id,
        prescritoPorNome: u.nome,
      ),
    );
    if (!mounted) return;
    avisar(
      context,
      'Exercício enviado ao portal de ${_pac.primeiroNome}. '
      '${_pac.responsavelNome.isEmpty ? '' : '${_pac.responsavelNome} já pode ver.'}',
    );
    context.go(Rotas.atendimento(_ag.id));
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final nome = _pac.primeiroNome;
    return Form(
      key: _form,
      child: Conteudo(
        children: [
          Row(
            children: [
              BotaoCinza(
                rotulo: 'Voltar ao atendimento',
                icone: Icons.chevron_left,
                onPressed: () => context.go(Rotas.atendimento(_ag.id)),
              ),
              const Spacer(),
              Pilula.lilas(
                'Sessão nº ${_ag.sessaoNumero} • '
                '${_ag.status == StatusAgendamento.emAtendimento ? 'Ativa' : _ag.status.rotulo}',
                ponto: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Cartao(
            child: Row(
              children: [
                Avatar(_pac.nome, tamanho: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Salvar exercício', style: TemaApp.titulo(size: 22)),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Plano de ',
                              style: TemaApp.corpo(color: Cores.textoSuave),
                            ),
                            TextSpan(
                              text:
                                  '${_pac.nome} (${Formatos.idadeTexto(_pac.dataNascimento, agora)})',
                              style: TemaApp.corpo(
                                color: Cores.primaria,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Cores.primaria,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconeQuadrado(
                  Icons.phonelink_ring_outlined,
                  fundo: Color(0x33FFFFFF),
                  cor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vai para o app da família',
                        style: TemaApp.titulo(size: 20, color: Colors.white),
                      ),
                      Text(
                        'Assim que salvar, o exercício aparece no app de $nome.',
                        style: TemaApp.corpo(size: 15, color: Colors.white),
                      ),
                      if (_pac.responsavelNome.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Pilula(
                          'Aparece no portal de ${_pac.responsavelNome} (${_pac.parentesco})',
                          icone: Icons.notifications_active_outlined,
                          fundo: const Color(0x33FFFFFF),
                          cor: Colors.white,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Sobrelinha('Configuração')),
                    Pilula(_pac.area),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _objetivo,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo',
                    prefixIcon: Icon(Icons.graphic_eq),
                  ),
                  items: [
                    for (final o in _objetivos)
                      DropdownMenuItem(value: o, child: Text(o)),
                  ],
                  onChanged: (v) => setState(() => _objetivo = v!),
                ),
                const SizedBox(height: 12),
                Bloco(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _titulo,
                              style: TemaApp.titulo(size: 16),
                              decoration: const InputDecoration(
                                labelText: 'Título do exercício',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) =>
                                  Validacao.obrigatorio(v, 'Título'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Pilula.menta('Fase $_fase de 4'),
                              Row(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Fase anterior',
                                    onPressed: _fase > 1
                                        ? () => setState(() => _fase--)
                                        : null,
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Próxima fase',
                                    onPressed: _fase < 4
                                        ? () => setState(() => _fase++)
                                        : null,
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descricao,
                        decoration: const InputDecoration(
                          labelText: 'Descrição curta',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Palavras do exercício:',
                        style: TemaApp.corpo(size: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in _estimulos)
                            InputChip(
                              avatar: Text(e.emoji),
                              label: Text(e.palavra),
                              backgroundColor: Colors.white,
                              onDeleted: () =>
                                  setState(() => _estimulos.remove(e)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _novaPalavra,
                              onSubmitted: (_) => _adicionarPalavra(),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Adicionar palavra (ex.: sorvete)',
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Adicionar estímulo',
                            onPressed: _adicionarPalavra,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Opcao(
                              icone: Icons.repeat,
                              rotulo: 'Frequência',
                              valor: _frequencia,
                              opcoes: _frequencias,
                              aoEscolher: (v) =>
                                  setState(() => _frequencia = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Opcao(
                              icone: Icons.timer_outlined,
                              rotulo: 'Duração',
                              valor: '$_duracao minutos',
                              opcoes: [for (final d in _duracoes) '$d minutos'],
                              aoEscolher: (v) => setState(
                                () => _duracao = int.parse(v.split(' ').first),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _Opcao(
                        icone: Icons.flag_outlined,
                        rotulo: 'Meta semanal',
                        valor: '$_meta práticas',
                        opcoes: const [
                          '3 práticas',
                          '4 práticas',
                          '5 práticas',
                          '7 práticas',
                        ],
                        aoEscolher: (v) => setState(
                          () => _meta = int.parse(v.split(' ').first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Bloco(
                        cor: Cores.container,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Cores.primaria,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reforço positivo: +1 estrela lúdica para $nome '
                                'a cada prática registrada no app.',
                                style: TemaApp.corpo(size: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instrucao,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Instrução clínica (opcional)',
                    hintText: 'Ex.: língua suave atrás dos dentes',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite_border),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Orientação para a família',
                        style: TemaApp.titulo(size: 20),
                      ),
                    ),
                    Text(
                      'Editável',
                      style: TemaApp.corpo(
                        size: 12,
                        color: Cores.primaria,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'A família vê esta mensagem no exercício:',
                  style: TemaApp.corpo(size: 13),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _orientacao,
                  maxLines: 5,
                  maxLength: 300,
                  style: TemaApp.corpo(size: 15, height: 1.5),
                  decoration: const InputDecoration(
                    fillColor: Cores.containerBaixo,
                  ),
                  validator: (v) => Validacao.obrigatorio(v, 'A orientação'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Atividades no App de $nome',
                        style: TemaApp.titulo(size: 20),
                      ),
                    ),
                    Text(
                      '${widget.dados.exercicios.length} registros',
                      style: TemaApp.corpo(size: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ItemAtividade(
                  titulo: _titulo.text.isEmpty
                      ? 'Nova prescrição'
                      : _titulo.text,
                  detalhe: 'Nova prescrição',
                  etiqueta: const Pilula.menta('Atribuindo'),
                  ativo: true,
                ),
                for (final e in widget.dados.exercicios)
                  _ItemAtividade(
                    titulo: e.titulo,
                    detalhe: e.concluido
                        ? 'Concluído • ${e.praticasSemana}/${e.metaSemanal} práticas'
                        : '${e.duracaoMin} min • ${e.praticasSemana} de ${e.metaSemanal} feitos',
                    etiqueta: e.concluido
                        ? const Pilula(
                            'Concluído',
                            fundo: Cores.primariaContainer,
                            cor: Colors.white,
                          )
                        : const Pilula('Ativo'),
                    concluido: e.concluido,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Bloco(
            cor: Cores.secundariaContainer,
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status: pronto para envio. $nome receberá na aba '
                    'Exercícios do Portal do Cliente.',
                    style: TemaApp.corpo(size: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: _enviando ? null : _atribuir,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                'Confirmar e Atribuir ao Portal de $nome',
                textAlign: TextAlign.center,
                style: TemaApp.titulo(size: 17, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.aoEscolher,
  });
  final IconData icone;
  final String rotulo;
  final String valor;
  final List<String> opcoes;
  final ValueChanged<String> aoEscolher;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Alterar $rotulo',
    onSelected: aoEscolher,
    itemBuilder: (_) => [
      for (final o in opcoes) PopupMenuItem(value: o, child: Text(o)),
    ],
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16),
              const SizedBox(width: 6),
              Text(rotulo, style: TemaApp.corpo(size: 12)),
              const Spacer(),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(valor, style: TemaApp.corpo(size: 16, weight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _ItemAtividade extends StatelessWidget {
  const _ItemAtividade({
    required this.titulo,
    required this.detalhe,
    required this.etiqueta,
    this.ativo = false,
    this.concluido = false,
  });
  final String titulo;
  final String detalhe;
  final Widget etiqueta;
  final bool ativo;
  final bool concluido;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Cores.containerBaixo,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(
          concluido ? Icons.check_circle_outline : Icons.circle,
          size: concluido ? 18 : 10,
          color: ativo ? Cores.primaria : Cores.contornoSuave,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TemaApp.corpo(size: 15, weight: FontWeight.w700)
                    .copyWith(
                      decoration: concluido ? TextDecoration.lineThrough : null,
                    ),
              ),
              Text(
                detalhe,
                style: TemaApp.corpo(
                  size: 12,
                  color: ativo ? Cores.primaria : Cores.textoSuave,
                ),
              ),
            ],
          ),
        ),
        etiqueta,
      ],
    ),
  );
}
