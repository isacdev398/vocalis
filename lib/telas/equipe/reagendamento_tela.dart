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
import '../../modelos/paciente.dart';
import '../../modelos/solicitacao.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';

class _Dados {
  _Dados(this.solicitacao, this.agendamentos, this.paciente);
  final SolicitacaoReagendamento? solicitacao;
  final List<Agendamento> agendamentos;
  final Paciente? paciente;
}

class ReagendamentoTela extends StatelessWidget {
  const ReagendamentoTela({super.key, required this.solicitacaoId});
  final String solicitacaoId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    return Observar<_Dados>(
      chave: (repo, solicitacaoId),
      stream: () => repo
          .solicitacao(solicitacaoId)
          .switchMap(
            (s) => Rx.combineLatest2(
              repo.agendamentos(),
              s == null
                  ? Stream<Paciente?>.value(null)
                  : repo.paciente(s.pacienteId),
              (List<Agendamento> a, Paciente? p) => _Dados(s, a, p),
            ),
          ),
      builder: (context, d) {
        final s = d.solicitacao;
        if (s == null) {
          return const EstadoVazio(
            icone: Icons.search_off,
            titulo: 'Solicitação não encontrada',
          );
        }
        return _Conteudo(dados: d, solicitacao: s);
      },
    );
  }
}

class _Conteudo extends StatefulWidget {
  const _Conteudo({required this.dados, required this.solicitacao});
  final _Dados dados;
  final SolicitacaoReagendamento solicitacao;

  @override
  State<_Conteudo> createState() => _ConteudoState();
}

class _ConteudoState extends State<_Conteudo> {
  bool _whatsapp = true;
  late final _mensagem = TextEditingController(text: _mensagemPadrao());
  bool _processando = false;

  SolicitacaoReagendamento get s => widget.solicitacao;

  String _mensagemPadrao([DateTime? horario]) {
    final h = horario ?? s.horarioPretendido;
    return 'Olá, ${Formatos.primeiroNome(s.responsavelNome)}! Confirmamos a '
        'transferência da sessão de ${s.pacienteNome.split(' ').first} para '
        '${Formatos.diaSemana(h)}, ${Formatos.diaMes(h)} às ${Formatos.hora(h)} '
        'com ${s.profissionalNome} na ${s.sala}. Um abraço carinhoso da equipe '
        'Vocalis!';
  }

  @override
  void dispose() {
    _mensagem.dispose();
    super.dispose();
  }

  Agendamento? get _agendamento => widget.dados.agendamentos
      .where((a) => a.id == s.agendamentoId)
      .firstOrNull;

  Disponibilidade _checar(DateTime inicio) {
    final dur =
        _agendamento?.duracao ??
        const Duration(minutes: Salas.duracaoPadraoMin);
    return AgendaLogica.verificar(
      widget.dados.agendamentos,
      profissionalId: s.profissionalId,
      sala: s.sala,
      inicio: inicio,
      fim: inicio.add(dur),
      ignorarId: s.agendamentoId,
    );
  }

  Future<void> _confirmar(DateTime horario) async {
    final sessao = context.read<Sessao>();
    final repo = context.read<ClinicaRepositorio>();
    setState(() => _processando = true);
    await repo.aprovarSolicitacao(
      s,
      novoInicio: horario,
      duracao:
          _agendamento?.duracao ??
          const Duration(minutes: Salas.duracaoPadraoMin),
      por: sessao.usuario!.nome,
    );
    if (!mounted) return;
    if (_whatsapp) avisarSimulado(context, 'Mensagem de WhatsApp');
    avisar(
      context,
      'Horário confirmado: ${Formatos.diaHoraCurto(horario)}. '
      'Portal do Cliente e agenda atualizados.',
    );
    context.go(Rotas.agenda);
  }

  Future<void> _recusar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recusar solicitação?'),
        content: Text(
          'O horário atual (${Formatos.diaHoraCurto(s.horarioAtual)}) será mantido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.erroForte),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nome = context.read<Sessao>().usuario!.nome;
    await context.read<ClinicaRepositorio>().recusarSolicitacao(
      s.id,
      por: nome,
    );
    if (mounted) {
      avisar(context, 'Solicitação recusada. Horário atual mantido.');
      context.go(Rotas.agenda);
    }
  }

  Future<void> _sugerirOutro() async {
    final escolhido = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Cores.superficie,
      builder: (_) => _EscolherHorario(
        agendamentos: widget.dados.agendamentos,
        profissionalId: s.profissionalId,
        diaInicial: s.horarioPretendido,
        profissionalNome: s.profissionalNome,
      ),
    );
    if (escolhido == null || !mounted) return;
    _mensagem.text = _mensagemPadrao(escolhido);
    await _confirmar(escolhido);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sessao>().usuario!;
    final p = widget.dados.paciente;
    final checagem = _checar(s.horarioPretendido);
    final agora = DateTime.now();

    return Conteudo(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => context.go(Rotas.agenda),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar para a agenda'),
            ),
            const Spacer(),
            Flexible(
              child: Pilula.lilas(
                'Recepção • ${usuario.nome}',
                icone: Icons.badge_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pedido de troca de horário',
          style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: switch (s.status) {
            StatusSolicitacao.pendente => const Pilula.lilas(
              'Esperando a recepção',
              ponto: true,
            ),
            StatusSolicitacao.aprovada => Pilula.sucesso(
              'Aprovada por ${s.resolvidoPor}',
              icone: Icons.check,
            ),
            StatusSolicitacao.recusada => Pilula.erro(
              'Recusada por ${s.resolvidoPor}',
              icone: Icons.close,
            ),
          },
        ),
        const SizedBox(height: 16),

        // paciente
        Cartao(
          child: Column(
            children: [
              Row(
                children: [
                  Avatar(s.pacienteNome, tamanho: 56, indicador: Cores.sucesso),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.pacienteNome,
                                style: TemaApp.titulo(size: 20),
                              ),
                            ),
                            if (p != null)
                              Text(
                                Formatos.idadeTexto(p.dataNascimento, agora),
                                style: TemaApp.corpo(
                                  size: 13,
                                  color: Cores.textoSuave,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${s.responsavelNome}'
                          '${p?.parentesco.isNotEmpty == true ? ' (${p!.parentesco} / Resp.)' : ''}',
                          style: TemaApp.corpo(color: Cores.textoSuave),
                        ),
                        if (p != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Pilula(p.convenio, icone: Icons.shield_outlined),
                              Text(p.area, style: TemaApp.corpo(size: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BotaoCinza(
                      rotulo: 'WhatsApp',
                      icone: Icons.chat_outlined,
                      onPressed: () => avisarSimulado(context, 'WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BotaoCinza(
                      rotulo: 'Ligar',
                      icone: Icons.call_outlined,
                      onPressed: () => avisarSimulado(
                        context,
                        'Ligação para ${p?.telefone ?? 'responsável'}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(child: Text('Horários', style: TemaApp.titulo(size: 20))),
            Text('Protocolo #${s.protocolo}', style: TemaApp.corpo(size: 12)),
          ],
        ),
        const SizedBox(height: 12),
        _CartaoHorario(
          rotulo: 'Horário atual agendado',
          etiqueta: const Pilula('Reservado'),
          inicio: s.horarioAtual,
          duracao: _agendamento?.duracao,
          profissional: s.profissionalNome,
          sala: s.sala,
          faixa: Cores.secundaria,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: CircleAvatar(
              backgroundColor: Cores.menta,
              child: Icon(Icons.swap_vert, color: Cores.primaria),
            ),
          ),
        ),
        _CartaoHorario(
          rotulo: 'Novo horário solicitado',
          etiqueta: const Pilula.menta(
            'Preferência da família',
            icone: Icons.favorite_border,
          ),
          inicio: s.horarioPretendido,
          duracao: _agendamento?.duracao,
          profissional: s.profissionalNome,
          sala: s.sala,
          faixa: Cores.primaria,
          destaque: true,
          motivo: s.motivo,
          responsavel: p?.parentesco.isNotEmpty == true
              ? 'Motivo informado pela ${p!.parentesco.toLowerCase()}'
              : 'Motivo informado pelo responsável',
        ),
        const SizedBox(height: 20),

        // checagem de conflito
        Cartao(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconeQuadrado(
                    Icons.published_with_changes,
                    fundo: Cores.menta,
                    tamanho: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conflitos de horário',
                      style: TemaApp.titulo(size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ItemChecagem(
                ok: checagem.profissionalLivre,
                titulo: checagem.profissionalLivre
                    ? '${s.profissionalNome} tem vaga livre'
                    : '${s.profissionalNome} já tem atendimento',
                texto: checagem.profissionalLivre
                    ? '${Formatos.diaHoraCurto(s.horarioPretendido)} está desocupado na grade.'
                    : 'Conflito com ${checagem.conflitos.where((c) => c.profissionalId == s.profissionalId).map((c) => '${c.pacienteNome} (${Formatos.hora(c.inicio)})').join(', ')}.',
              ),
              _ItemChecagem(
                ok: checagem.salaLivre,
                titulo: checagem.salaLivre
                    ? '${s.sala} desimpedida'
                    : '${s.sala} ocupada',
                texto: checagem.salaLivre
                    ? 'A sala está livre nesse horário.'
                    : 'Outro atendimento usa a sala neste horário.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (s.pendente) ...[
          Cartao(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Cores.primaria,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mensagem para a família',
                        style: TemaApp.titulo(size: 18),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _whatsapp,
                  onChanged: (v) => setState(() => _whatsapp = v!),
                  title: Text(
                    'Avisar pelo WhatsApp',
                    style: TemaApp.corpo(weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Mensagem acolhedora para ${s.responsavelNome} (simulado)',
                    style: TemaApp.corpo(size: 12),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Prévia da mensagem que será enviada:',
                        style: TemaApp.corpo(size: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _mensagem.text = _mensagemPadrao(),
                      child: const Text('Restaurar padrão'),
                    ),
                  ],
                ),
                TextField(
                  controller: _mensagem,
                  enabled: _whatsapp,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    fillColor: Cores.containerBaixo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Bloco(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Cores.menta,
                  child: Icon(Icons.sync, color: Cores.primaria, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Muda na hora no app da família e na agenda de '
                    '${s.profissionalNome}.',
                    style: TemaApp.corpo(size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _processando || !checagem.livre
                  ? null
                  : () => _confirmar(s.horarioPretendido),
              icon: const Icon(Icons.check),
              label: Text(
                'Confirmar ${Formatos.diaSemanaCurto(s.horarioPretendido)}, '
                '${Formatos.diaMes(s.horarioPretendido)} às ${Formatos.hora(s.horarioPretendido)}',
                style: TemaApp.titulo(size: 17, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Cores.borda),
              backgroundColor: Colors.white,
              minimumSize: const Size(48, 52),
            ),
            onPressed: _processando ? null : _sugerirOutro,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Sugerir outro horário'),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Cores.erroForte),
            onPressed: _processando ? null : _recusar,
            icon: const Icon(Icons.close),
            label: Text(
              'Recusar '
              '(${Formatos.diaSemanaCurto(s.horarioAtual)}, ${Formatos.hora(s.horarioAtual)})',
            ),
          ),
        ] else
          Bloco(
            cor: s.status == StatusSolicitacao.aprovada
                ? Cores.sucessoFundo
                : Cores.erroFundo,
            child: Text(
              s.status == StatusSolicitacao.aprovada
                  ? 'Troca confirmada para ${Formatos.diaHoraCurto(s.horarioFinal ?? s.horarioPretendido)}'
                        '${s.resolvidoEm == null ? '' : ' em ${Formatos.diaMes(s.resolvidoEm!)} às ${Formatos.hora(s.resolvidoEm!)}'}.'
                  : 'Solicitação recusada. O horário original foi mantido.',
              style: TemaApp.corpo(weight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _CartaoHorario extends StatelessWidget {
  const _CartaoHorario({
    required this.rotulo,
    required this.etiqueta,
    required this.inicio,
    required this.profissional,
    required this.sala,
    required this.faixa,
    this.duracao,
    this.destaque = false,
    this.motivo,
    this.responsavel,
  });
  final String rotulo;
  final Widget etiqueta;
  final DateTime inicio;
  final Duration? duracao;
  final String profissional;
  final String sala;
  final Color faixa;
  final bool destaque;
  final String? motivo;
  final String? responsavel;

  @override
  Widget build(BuildContext context) {
    final fim = inicio.add(
      duracao ?? const Duration(minutes: Salas.duracaoPadraoMin),
    );
    return Cartao(
      faixa: faixa,
      elevado: destaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: destaque ? Cores.primaria : Cores.textoSuave,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Sobrelinha(
                  rotulo,
                  cor: destaque ? Cores.primaria : Cores.textoSuave,
                ),
              ),
              Flexible(child: etiqueta),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                Formatos.diaCompleto(inicio),
                style: TemaApp.titulo(size: 22, weight: FontWeight.w600),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${Formatos.hora(inicio)} - ${Formatos.hora(fim)}',
                  style: TemaApp.corpo(
                    size: 15,
                    weight: FontWeight.w700,
                    color: destaque ? Cores.primaria : Cores.texto,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Bloco(
            child: Row(
              children: [
                const Icon(Icons.medical_services_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(profissional)),
                const Icon(Icons.meeting_room_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(sala, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          if (motivo != null && motivo!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Bloco(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_quote, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${responsavel ?? 'Motivo'}:',
                        style: TemaApp.corpo(size: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"$motivo"',
                    style: TemaApp.corpo(size: 15)
                        .copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemChecagem extends StatelessWidget {
  const _ItemChecagem({
    required this.ok,
    required this.titulo,
    required this.texto,
  });
  final bool ok;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: ok ? Cores.primaria : Cores.erroForte,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TemaApp.corpo(size: 15, weight: FontWeight.w700),
              ),
              Text(texto, style: TemaApp.corpo(color: Cores.textoSuave)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EscolherHorario extends StatefulWidget {
  const _EscolherHorario({
    required this.agendamentos,
    required this.profissionalId,
    required this.profissionalNome,
    required this.diaInicial,
  });
  final List<Agendamento> agendamentos;
  final String profissionalId;
  final String profissionalNome;
  final DateTime diaInicial;

  @override
  State<_EscolherHorario> createState() => _EscolherHorarioState();
}

class _EscolherHorarioState extends State<_EscolherHorario> {
  late DateTime _dia = widget.diaInicial.inicioDoDia;

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final livres = AgendaLogica.horariosLivres(
      widget.agendamentos,
      _dia,
      profissionalId: widget.profissionalId,
    ).where((h) => h.isAfter(agora)).toList();
    final dias = [
      for (var i = 0; i < 14; i++)
        DateTime(agora.year, agora.month, agora.day + i),
    ].where((d) => d.weekday <= DateTime.friday).take(8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sugerir outro horário', style: TemaApp.titulo(size: 20)),
          Text(
            'Vagas livres de ${widget.profissionalNome}',
            style: TemaApp.corpo(color: Cores.textoSuave),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in dias)
                ChoiceChip(
                  label: Text(
                    '${Formatos.diaSemanaCurto(d)} ${Formatos.diaMes(d)}',
                  ),
                  selected: d.mesmoDia(_dia),
                  onSelected: (_) => setState(() => _dia = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Sobrelinha('Horários disponíveis'),
          const SizedBox(height: 8),
          if (livres.isEmpty)
            Text(
              'Nenhuma vaga neste dia.',
              style: TemaApp.corpo(color: Cores.textoSuave),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in livres)
                ActionChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(Formatos.hora(h)),
                  onPressed: () => Navigator.pop(context, h),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
