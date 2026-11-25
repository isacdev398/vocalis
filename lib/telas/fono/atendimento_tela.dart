import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../estado/sessao.dart';
import '../../logica/agenda_logica.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/evolucao.dart';
import '../../modelos/paciente.dart';
import '../../modelos/usuario.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';
import '../cliente/exercicios_tela.dart' show OndaSonora;

class _DadosAtendimento {
  _DadosAtendimento(
    this.agendamento,
    this.paciente,
    this.evolucao,
    this.historico,
    this.doPaciente,
  );
  final Agendamento? agendamento;
  final Paciente? paciente;
  final Evolucao? evolucao;
  final List<Evolucao> historico;
  final List<Agendamento> doPaciente;
}

class AtendimentoTela extends StatelessWidget {
  const AtendimentoTela({super.key, required this.agendamentoId});
  final String agendamentoId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    return Observar<_DadosAtendimento>(
      chave: (repo, agendamentoId),
      stream: () => repo.agendamento(agendamentoId).switchMap((a) {
        if (a == null) {
          return Stream.value(_DadosAtendimento(null, null, null, [], []));
        }
        return Rx.combineLatest4(
          repo.paciente(a.pacienteId),
          repo.evolucao(a.id),
          repo.evolucoesDoPaciente(a.pacienteId),
          repo.agendamentosDoPaciente(a.pacienteId),
          (Paciente? p, Evolucao? e, List<Evolucao> h, List<Agendamento> ag) =>
              _DadosAtendimento(a, p, e, h, ag),
        );
      }),
      builder: (context, d) {
        if (d.agendamento == null || d.paciente == null) {
          return const EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Atendimento não encontrado',
          );
        }
        return _EditorSoap(key: ValueKey(d.agendamento!.id), dados: d);
      },
    );
  }
}

class _EditorSoap extends StatefulWidget {
  const _EditorSoap({super.key, required this.dados});
  final _DadosAtendimento dados;

  @override
  State<_EditorSoap> createState() => _EditorSoapState();
}

class _EditorSoapState extends State<_EditorSoap> {
  late final _s = TextEditingController(text: _ev?.subjetivo);
  late final _o = TextEditingController(text: _ev?.objetivo);
  late final _a = TextEditingController(text: _ev?.avaliacao);
  late final _p = TextEditingController(text: _ev?.plano);
  late final _acolhimento = TextEditingController(text: _ev?.acolhimento);
  late int _acertos = _ev?.acertos ?? 0;
  late int _tentativas = _ev?.tentativas ?? 0;

  Timer? _debounce;
  DateTime? _salvoEm;
  bool _salvando = false;
  bool _audioGravado = false;
  bool _gravandoAudio = false;

  Evolucao? get _ev => widget.dados.evolucao;
  Agendamento get _ag => widget.dados.agendamento!;
  Paciente get _pac => widget.dados.paciente!;

  @override
  void initState() {
    super.initState();
    for (final c in [_s, _o, _a, _p, _acolhimento]) {
      c.addListener(_agendarSalvamento);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_s, _o, _a, _p, _acolhimento]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _podeEditar(Usuario u) =>
      !(_ev?.finalizada ?? false) &&
      (u.id == _ag.profissionalId || u.perfil == Perfil.dono);

  Evolucao _montar() {
    final u = context.read<Sessao>().usuario!;
    return Evolucao(
      id: _ag.id,
      pacienteId: _ag.pacienteId,
      profissionalId: _ag.profissionalId,
      profissionalNome: u.id == _ag.profissionalId
          ? u.nome
          : _ag.profissionalNome,
      data: _ag.inicio,
      subjetivo: _s.text.trim(),
      objetivo: _o.text.trim(),
      avaliacao: _a.text.trim(),
      plano: _p.text.trim(),
      acolhimento: _acolhimento.text.trim(),
      acertos: _acertos,
      tentativas: _tentativas,
      sessaoNumero: _ag.sessaoNumero,
    );
  }

  // salva o rascunho 1,5 s depois de parar de digitar
  void _agendarSalvamento() {
    if (_ev?.finalizada ?? false) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _salvarRascunho);
  }

  Future<void> _salvarRascunho({bool avisarUsuario = false}) async {
    _debounce?.cancel();
    if (!mounted) return;
    setState(() => _salvando = true);
    await context.read<ClinicaRepositorio>().salvarEvolucao(_montar());
    if (!mounted) return;
    setState(() {
      _salvando = false;
      _salvoEm = DateTime.now();
    });
    if (avisarUsuario) avisar(context, 'Rascunho salvo.');
  }

  Future<void> _finalizar() async {
    final e = _montar();
    final faltando = [
      if (e.subjetivo.isEmpty) 'Subjetivo',
      if (e.objetivo.isEmpty) 'Objetivo',
      if (e.avaliacao.isEmpty) 'Avaliação',
      if (e.plano.isEmpty) 'Plano',
    ];
    if (faltando.isNotEmpty) {
      avisar(context, 'Preencha antes de assinar: ${faltando.join(', ')}.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar e assinar?'),
        content: const Text(
          'A evolução fica bloqueada para edição e o atendimento é marcado '
          'como concluído na agenda da clínica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assinar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _debounce?.cancel();
    await context.read<ClinicaRepositorio>().finalizarEvolucao(e);
    if (!mounted) return;
    avisar(
      context,
      'Evolução assinada. Sessão #${_ag.sessaoNumero} concluída.',
    );
    context.go(Rotas.agenda);
  }

  void _mudarPrecisao({int acertos = 0, int tentativas = 0}) {
    setState(() {
      _tentativas = (_tentativas + tentativas).clamp(0, 999);
      _acertos = (_acertos + acertos).clamp(0, _tentativas);
    });
    _agendarSalvamento();
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Sessao>().usuario!;
    final editar = _podeEditar(u);
    final agora = DateTime.now();
    final finalizada = _ev?.finalizada ?? false;
    final emAndamento = _ag.status == StatusAgendamento.emAtendimento;
    final proxima = AgendaLogica.proxima(
      widget.dados.doPaciente.where((a) => a.id != _ag.id).toList(),
      _ag.fim,
    );
    final precisao = _tentativas == 0 ? 0.0 : _acertos / _tentativas;

    return Conteudo(
      children: [
        // cabeçalho do profissional
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Cores.containerBaixo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Text(
                    finalizada
                        ? 'Assinada'
                        : emAndamento
                        ? 'Em atendimento'
                        : _ag.status.rotulo,
                    style: TemaApp.corpo(
                      weight: FontWeight.w700,
                      color: emAndamento ? Cores.primaria : Cores.textoSuave,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ag.profissionalNome,
                          style: TemaApp.titulo(size: 20),
                        ),
                        Text(
                          'Fonoaudiologia • Sessão #${_ag.sessaoNumero}',
                          style: TemaApp.corpo(size: 12),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Cores.borda),
                    ),
                    onPressed: () => _historico(context),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      'Histórico (${widget.dados.historico.where((e) => e.finalizada).length})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const IconeQuadrado(Icons.meeting_room_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ambiente', style: TemaApp.corpo(size: 12)),
                          Text(
                            _ag.sala,
                            style: TemaApp.corpo(
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Tempo de sessão', style: TemaApp.corpo(size: 12)),
                        Relogio(
                          builder: (_, agora) {
                            final inicio = _ag.iniciadoEm;
                            final dur = _ag.duracao.inMinutes;
                            if (!emAndamento || inicio == null) {
                              return Text(
                                '-- / $dur min',
                                style: TemaApp.corpo(
                                  size: 17,
                                  weight: FontWeight.w700,
                                  tabular: true,
                                ),
                              );
                            }
                            final d = agora.difference(inicio);
                            final mm = d.inMinutes.toString().padLeft(2, '0');
                            final ss = (d.inSeconds % 60).toString().padLeft(
                              2,
                              '0',
                            );
                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$mm:$ss',
                                    style: TemaApp.corpo(
                                      size: 17,
                                      weight: FontWeight.w700,
                                      color: Cores.primaria,
                                      tabular: true,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / $dur min',
                                    style: TemaApp.corpo(size: 13),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!emAndamento && !finalizada && _ag.status.ativo && editar) ...[
          Bloco(
            cor: Cores.alertaFundo,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Cores.alertaTexto),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'O atendimento ainda não começou '
                    '(${_ag.status.rotulo.toLowerCase()}).',
                    style: TemaApp.corpo(color: Cores.alertaTexto),
                  ),
                ),
                FilledButton(
                  onPressed: () => context
                      .read<ClinicaRepositorio>()
                      .iniciarAtendimento(_ag.id),
                  child: const Text('Iniciar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (finalizada) ...[
          const Bloco(
            cor: Cores.sucessoFundo,
            child: Row(
              children: [
                Icon(Icons.verified_outlined, color: Cores.sucessoTexto),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evolução assinada. Somente leitura (sigilo profissional).',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // paciente
        Cartao(
          faixa: Cores.primaria,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(_pac.nome, tamanho: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_pac.nome, style: TemaApp.titulo(size: 22)),
                            Pilula(
                              Formatos.idadeTexto(_pac.dataNascimento, agora),
                            ),
                          ],
                        ),
                        if (_pac.responsavelNome.isNotEmpty)
                          Text(
                            'Resp: ${_pac.responsavelNome} (${_pac.parentesco})',
                            style: TemaApp.corpo(color: Cores.textoSuave),
                          ),
                      ],
                    ),
                  ),
                  if (_pac.foco.isNotEmpty)
                    Pilula.menta(_pac.foco, icone: Icons.graphic_eq),
                ],
              ),
              const SizedBox(height: 12),
              Bloco(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_outlined, size: 16),
                        SizedBox(width: 6),
                        Sobrelinha('Hipótese / foco terapêutico'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pac.hipotese.isEmpty ? 'Não informada' : _pac.hipotese,
                      style: TemaApp.corpo(size: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Bloco(
                cor: Cores.secundariaContainer.withValues(alpha: 0.6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.sentiment_satisfied_alt, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Sobrelinha('Acolhimento da sessão'),
                          TextField(
                            controller: _acolhimento,
                            enabled: editar,
                            maxLines: null,
                            style: TemaApp.corpo(size: 15),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                              hintText: 'Como o paciente chegou? Ex.: engajado e sorridente.',
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
        const SizedBox(height: 20),

        // SOAP
        Row(
          children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Evolução (SOAP)', style: TemaApp.titulo(size: 20)),
            ),
            if (editar)
              Row(
                children: [
                  Icon(
                    _salvando ? Icons.sync : Icons.cloud_done_outlined,
                    size: 16,
                    color: Cores.textoSuave,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _salvando
                        ? 'Salvando…'
                        : _salvoEm != null
                        ? 'Salvo às ${Formatos.hora(_salvoEm!)}'
                        : 'Salvando automaticamente',
                    style: TemaApp.corpo(size: 12),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        _CartaoSoap(
          letra: 'S',
          titulo: 'Subjetivo',
          rotulo: 'Relato da família',
          controller: _s,
          editar: editar,
          exemplo:
              'Ex.: Mãe relata boa adesão ao treino domiciliar, mas nota omissão '
              'pontual do fonema /s/ em conversa espontânea.',
        ),
        const SizedBox(height: 12),
        _CartaoSoap(
          letra: 'O',
          titulo: 'Objetivo',
          rotulo: 'Medições',
          controller: _o,
          editar: editar,
          exemplo:
              'Ex.: Treino articulatório isolado e em sílabas CV. Repetição '
              'monitorada de "sapato", "sapo" e "sino".',
          extra: Bloco(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Precisão articulatória',
                        style: TemaApp.corpo(size: 13),
                      ),
                    ),
                    Text(
                      '${(precisao * 100).round()}% ($_acertos/$_tentativas)',
                      style: TemaApp.corpo(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Cores.primaria,
                        tabular: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BarraProgresso(precisao),
                if (editar) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(40, 42),
                            backgroundColor: Cores.sucesso,
                          ),
                          onPressed: () =>
                              _mudarPrecisao(acertos: 1, tentativas: 1),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Acerto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(40, 42),
                            backgroundColor: Cores.erro,
                          ),
                          onPressed: () => _mudarPrecisao(tentativas: 1),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Erro'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Zerar contagem',
                        onPressed: () {
                          setState(() {
                            _acertos = 0;
                            _tentativas = 0;
                          });
                          _agendarSalvamento();
                        },
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CartaoSoap(
          letra: 'A',
          titulo: 'Avaliação',
          rotulo: 'Avaliação',
          controller: _a,
          editar: editar,
          cor: Cores.secundaria,
          exemplo:
              'Ex.: Evolução favorável do ponto articulatório de /s/ alveolar.',
        ),
        const SizedBox(height: 12),
        _CartaoSoap(
          letra: 'P',
          titulo: 'Conduta',
          rotulo: 'Próximos passos',
          controller: _p,
          editar: editar,
          exemplo: 'Ex.: Prescrever reforço domiciliar do fonema /s/ no portal do cliente.',
          extra: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Cores.mentaSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_repeat, size: 18, color: Cores.primaria),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proxima == null
                        ? 'Próximo encontro: ainda não agendado'
                        : 'Próximo encontro: ${Formatos.diaMes(proxima.inicio)} '
                              'às ${Formatos.hora(proxima.inicio)} (${proxima.tipo})',
                    style: TemaApp.corpo(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Cores.primaria,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // áudio de referência
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Cores.mentaSuave,
                    child: Icon(Icons.mic_none, color: Cores.primaria),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Áudio de referência',
                          style: TemaApp.titulo(size: 18),
                        ),
                        Text(
                          'Guia para escuta de ${_pac.primeiroNome} em casa (simulado)',
                          style: TemaApp.corpo(size: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_audioGravado) const Pilula('referencia.mp3'),
                ],
              ),
              const SizedBox(height: 12),
              Bloco(
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: _gravandoAudio ? 'Parar' : 'Gravar referência',
                      style: IconButton.styleFrom(
                        backgroundColor: _gravandoAudio
                            ? Cores.erroForte
                            : Cores.primaria,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: editar
                          ? () {
                              setState(() {
                                if (_gravandoAudio) _audioGravado = true;
                                _gravandoAudio = !_gravandoAudio;
                              });
                              if (!_gravandoAudio) {
                                avisarSimulado(context, 'Gravação de áudio');
                              }
                            }
                          : null,
                      icon: Icon(_gravandoAudio ? Icons.stop : Icons.mic),
                    ),
                    const SizedBox(width: 12),
                    OndaSonora(ativa: _gravandoAudio),
                    const Spacer(),
                    Text(
                      _gravandoAudio
                          ? 'Gravando…'
                          : _audioGravado
                          ? 'Pronto para o app'
                          : 'Toque para gravar',
                      style: TemaApp.corpo(size: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ações
        if (Rotas.podeAcessar(u, Rotas.prescrever(_ag.id)))
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => context.go(Rotas.prescrever(_ag.id)),
              child: Row(
                children: [
                  const Icon(Icons.assignment_add),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Passar exercício para casa',
                      style: TemaApp.titulo(size: 16, color: Colors.white),
                    ),
                  ),
                  const Pilula.menta('Sincronizado'),
                ],
              ),
            ),
          ),
        if (editar) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BotaoCinza(
                  rotulo: 'Salvar rascunho',
                  icone: Icons.save_outlined,
                  onPressed: () => _salvarRascunho(avisarUsuario: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BotaoCinza(
                  rotulo: 'Finalizar e assinar',
                  icone: Icons.verified_outlined,
                  cor: Cores.containerAlto,
                  onPressed: _finalizar,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 14),
            const SizedBox(width: 4),
            Text(
              'Protegido por sigilo profissional.',
              style: TemaApp.corpo(size: 12),
            ),
          ],
        ),
      ],
    );
  }

  void _historico(BuildContext context) {
    final lista = widget.dados.historico
        .where((e) => e.finalizada && e.id != _ag.id)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Cores.superficie,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(
              'Histórico de ${_pac.primeiroNome}',
              style: TemaApp.titulo(size: 20),
            ),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              const EstadoVazio(
                icone: Icons.history,
                titulo: 'Nenhuma evolução anterior assinada',
              ),
            for (final e in lista) ...[
              Cartao(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${Formatos.data(e.data)} • Sessão #${e.sessaoNumero}',
                            style: TemaApp.titulo(size: 15),
                          ),
                        ),
                        if (e.tentativas > 0)
                          Pilula.menta('${e.precisaoPercentual}% precisão'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _linhaSoap('S', e.subjetivo),
                    _linhaSoap('O', e.objetivo),
                    _linhaSoap('A', e.avaliacao),
                    _linhaSoap('P', e.plano),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linhaSoap(String letra, String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$letra: ',
            style: TemaApp.corpo(
              weight: FontWeight.w700,
              color: Cores.primaria,
            ),
          ),
          TextSpan(text: texto, style: TemaApp.corpo()),
        ],
      ),
    ),
  );
}

class _CartaoSoap extends StatelessWidget {
  const _CartaoSoap({
    required this.letra,
    required this.titulo,
    required this.rotulo,
    required this.controller,
    required this.editar,
    required this.exemplo,
    this.cor = Cores.primaria,
    this.extra,
  });
  final String letra;
  final String titulo;
  final String rotulo;
  final TextEditingController controller;
  final bool editar;
  final String exemplo;
  final Color cor;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Cartao(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                letra,
                style: TemaApp.titulo(size: 15, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: TemaApp.titulo(size: 20))),
            Text(rotulo, style: TemaApp.corpo(size: 12)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: editar,
          minLines: 2,
          maxLines: null,
          style: TemaApp.corpo(size: 15, height: 1.5),
          decoration: InputDecoration(
            hintText: exemplo,
            hintMaxLines: 3,
            fillColor: editar ? Colors.white : Cores.containerBaixo,
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 10), extra!],
      ],
    ),
  );
}
