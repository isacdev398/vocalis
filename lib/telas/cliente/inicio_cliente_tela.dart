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
import '../../modelos/cobranca.dart';
import '../../modelos/exercicio.dart';
import '../../modelos/paciente.dart';
import '../../modelos/solicitacao.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';

class _DadosCliente {
  _DadosCliente(
    this.paciente,
    this.agendamentos,
    this.exercicios,
    this.cobrancas,
    this.solicitacoes,
  );
  final Paciente? paciente;
  final List<Agendamento> agendamentos;
  final List<Exercicio> exercicios;
  final List<Cobranca> cobrancas;
  final List<SolicitacaoReagendamento> solicitacoes;
}

class InicioClienteTela extends StatelessWidget {
  const InicioClienteTela({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sessao>().usuario!;
    final repo = context.watch<ClinicaRepositorio>();
    final pid = usuario.pacienteId ?? '';

    return Observar<_DadosCliente>(
      chave: (repo, pid),
      stream: () => Rx.combineLatest5(
        repo.paciente(pid),
        repo.agendamentosDoPaciente(pid),
        repo.exerciciosDoPaciente(pid),
        repo.cobrancasDoPaciente(pid),
        repo.solicitacoesDoPaciente(pid),
        _DadosCliente.new,
      ),
      builder: (context, d) {
        final p = d.paciente;
        if (p == null) {
          return const EstadoVazio(
            icone: Icons.child_care,
            titulo: 'Nenhum paciente vinculado',
            texto: 'Peça à recepção para vincular o paciente à sua conta.',
          );
        }
        final agora = DateTime.now();
        final proxima = AgendaLogica.proxima(d.agendamentos, agora);
        final exercicio = d.exercicios.where((e) => !e.concluido).firstOrNull;
        final pendencias = d.cobrancas.where((c) => !c.paga).toList();
        final solicitacao = proxima == null
            ? null
            : d.solicitacoes
                  .where((s) => s.agendamentoId == proxima.id)
                  .firstOrNull;

        return Conteudo(
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Olá, ${Formatos.primeiroNome(usuario.nome)}',
                    style: TemaApp.titulo(size: 26, letterSpacing: -0.3),
                  ),
                ),
                if (usuario.parentesco.isNotEmpty &&
                    usuario.parentesco != 'Próprio paciente')
                  Pilula.lilas('${usuario.parentesco} da ${p.primeiroNome}'),
              ],
            ),
            const SizedBox(height: 14),
            _CartaoPaciente(paciente: p, agora: agora),
            const SizedBox(height: 16),
            _CartaoProximaConsulta(
              proxima: proxima,
              solicitacao: solicitacao,
              paciente: p,
              responsavel: usuario.nome,
              agora: agora,
            ),
            const SizedBox(height: 16),
            if (exercicio != null) ...[
              _CartaoExercicioHoje(exercicio: exercicio, paciente: p),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                const Expanded(child: Sobrelinha('Avisos e lembretes')),
                Text(
                  pendencias.isEmpty
                      ? 'Tudo em dia'
                      : '${pendencias.length} ${pendencias.length == 1 ? 'pendência' : 'pendências'}',
                  style: TemaApp.corpo(
                    size: 13,
                    color: Cores.primaria,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (pendencias.isEmpty)
              const Cartao(
                child: Row(
                  children: [
                    IconeQuadrado(Icons.check_circle_outline),
                    SizedBox(width: 12),
                    Expanded(child: Text('Nenhuma cobrança em aberto.')),
                  ],
                ),
              ),
            for (final c in pendencias) ...[
              _CartaoCobranca(cobranca: c, agora: agora),
              const SizedBox(height: 10),
            ],
            if (exercicio != null && exercicio.orientacaoPais.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Cores.container,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.sentiment_satisfied_alt,
                      color: Cores.primaria,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dica da Semana para ${Formatos.primeiroNome(usuario.nome)}',
                            style: TemaApp.titulo(size: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            exercicio.orientacaoPais,
                            style: TemaApp.corpo(size: 15, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CartaoPaciente extends StatelessWidget {
  const _CartaoPaciente({required this.paciente, required this.agora});
  final Paciente paciente;
  final DateTime agora;

  @override
  Widget build(BuildContext context) => Cartao(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Avatar(paciente.nome, tamanho: 52, indicador: Cores.sucesso),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: paciente.nome,
                      style: TemaApp.titulo(size: 16),
                    ),
                    TextSpan(
                      text:
                          '  (${Formatos.idadeTexto(paciente.dataNascimento, agora)})',
                      style: TemaApp.corpo(color: Cores.textoSuave),
                    ),
                  ],
                ),
              ),
              Text(
                'Em acompanhamento',
                style: TemaApp.corpo(
                  size: 13,
                  color: Cores.primaria,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        BotaoCinza(
          rotulo: 'Trocar',
          icone: Icons.expand_more,
          onPressed: () =>
              avisar(context, 'Só há um paciente vinculado a esta conta.'),
        ),
      ],
    ),
  );
}

class _CartaoProximaConsulta extends StatelessWidget {
  const _CartaoProximaConsulta({
    required this.proxima,
    required this.solicitacao,
    required this.paciente,
    required this.responsavel,
    required this.agora,
  });

  final Agendamento? proxima;
  final SolicitacaoReagendamento? solicitacao;
  final Paciente paciente;
  final String responsavel;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final a = proxima;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Cores.borda),
        boxShadow: Sombras.nivel2,
        gradient: const LinearGradient(
          colors: [Colors.white, Colors.white, Color(0xFFE9F8F5)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: a == null
          ? const EstadoVazio(
              icone: Icons.event_available,
              titulo: 'Nenhuma consulta marcada',
              texto: 'Fale com a recepção para agendar a próxima sessão.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_available, color: Cores.primaria),
                    const SizedBox(width: 8),
                    const Expanded(child: Sobrelinha('Próxima consulta')),
                    if (a.status == StatusAgendamento.agendado)
                      const Pilula.alerta('A confirmar', ponto: true)
                    else
                      Pilula.sucesso(
                        a.status == StatusAgendamento.confirmado
                            ? 'Confirmada'
                            : a.status.rotulo,
                        ponto: true,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  Formatos.diaCompleto(a.inicio),
                  style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Cores.primaria, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${Formatos.hora(a.inicio)} às ${Formatos.hora(a.fim)}',
                      style: TemaApp.corpo(
                        size: 18,
                        weight: FontWeight.w700,
                        color: Cores.primaria,
                        tabular: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chegue 10 minutos antes',
                        style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Bloco(
                  child: Row(
                    children: [
                      Avatar(a.profissionalNome, tamanho: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.profissionalNome,
                              style: TemaApp.titulo(size: 16),
                            ),
                            Text(
                              '${paciente.area} • ${a.tipo}',
                              style: TemaApp.corpo(
                                size: 13,
                                color: Cores.textoSuave,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.meeting_room_outlined,
                                  size: 16,
                                  color: Cores.primaria,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    a.sala,
                                    style: TemaApp.corpo(
                                      size: 13,
                                      color: Cores.primaria,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _detalhes(context, a),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Ver detalhes da sessão'),
                  ),
                ),
                const SizedBox(height: 8),
                _situacaoTroca(context, a),
              ],
            ),
    );
  }

  Widget _situacaoTroca(BuildContext context, Agendamento a) {
    final s = solicitacao;
    if (s != null && s.pendente) {
      return Bloco(
        cor: Cores.alertaFundo,
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Cores.alertaTexto),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Troca solicitada para ${Formatos.diaHoraCurto(s.horarioPretendido)}. '
                'Aguardando confirmação da recepção.',
                style: TemaApp.corpo(color: Cores.alertaTexto),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (s != null && s.status == StatusSolicitacao.aprovada)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Bloco(
              cor: Cores.sucessoFundo,
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Cores.sucessoTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reagendamento confirmado pela recepção.',
                      style: TemaApp.corpo(color: Cores.sucessoTexto),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Center(
          child: TextButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              backgroundColor: Cores.superficie,
              builder: (_) => _FolhaReagendamento(
                agendamento: a,
                responsavel: responsavel,
                repo: context.read<ClinicaRepositorio>(),
              ),
            ),
            icon: const Icon(Icons.history, color: Cores.textoSuave),
            label: Text(
              'Solicitar reagendamento',
              style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
            ),
          ),
        ),
      ],
    );
  }

  void _detalhes(BuildContext context, Agendamento a) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sessão nº ${a.sessaoNumero}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linha(Icons.event, Formatos.diaCompleto(a.inicio)),
            _linha(
              Icons.schedule,
              '${Formatos.hora(a.inicio)} às ${Formatos.hora(a.fim)}',
            ),
            _linha(Icons.person_outline, a.profissionalNome),
            _linha(Icons.meeting_room_outlined, a.sala),
            _linha(Icons.category_outlined, a.tipo),
            const SizedBox(height: 8),
            Text(
              'Traga a agenda de exercícios e chegue 10 minutos antes.',
              style: TemaApp.corpo(color: Cores.textoSuave),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _linha(IconData i, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(i, size: 18, color: Cores.primaria),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ],
    ),
  );
}

class _FolhaReagendamento extends StatefulWidget {
  const _FolhaReagendamento({
    required this.agendamento,
    required this.responsavel,
    required this.repo,
  });
  final Agendamento agendamento;
  final String responsavel;
  final ClinicaRepositorio repo;

  @override
  State<_FolhaReagendamento> createState() => _FolhaReagendamentoState();
}

class _FolhaReagendamentoState extends State<_FolhaReagendamento> {
  late DateTime _dia;
  (int, int)? _horario;
  final _motivo = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _dia = _proximosDiasUteis().first;
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  List<DateTime> _proximosDiasUteis() {
    final hoje = DateTime.now().inicioDoDia;
    return [
      for (var i = 1; i <= 14; i++)
        DateTime(hoje.year, hoje.month, hoje.day + i),
    ].where((d) => d.weekday <= DateTime.friday).take(8).toList();
  }

  Future<void> _enviar() async {
    if (_horario == null) return;
    setState(() => _enviando = true);
    await widget.repo.solicitarReagendamento(
      agendamento: widget.agendamento,
      responsavelNome: widget.responsavel,
      novoHorario: _dia.comHora(_horario!.$1, _horario!.$2),
      motivo: _motivo.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    avisar(context, 'Pedido enviado! A recepção vai confirmar o novo horário.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Solicitar reagendamento', style: TemaApp.titulo(size: 20)),
            const SizedBox(height: 4),
            Text(
              'Atual: ${Formatos.diaHoraCurto(widget.agendamento.inicio)} '
              'com ${widget.agendamento.profissionalNome}',
              style: TemaApp.corpo(color: Cores.textoSuave),
            ),
            const SizedBox(height: 16),
            const Sobrelinha('Novo dia'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _proximosDiasUteis())
                  ChoiceChip(
                    label: Text(
                      '${Formatos.diaSemanaCurto(d)} ${Formatos.diaMes(d)}',
                    ),
                    selected: d == _dia,
                    onSelected: (_) => setState(() => _dia = d),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Sobrelinha('Horário preferido'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in [
                  ...Salas.grade.take(3),
                  (14, 0),
                  (15, 0),
                  (16, 30),
                ])
                  ChoiceChip(
                    label: Text(
                      '${h.$1.toString().padLeft(2, '0')}:${h.$2.toString().padLeft(2, '0')}',
                    ),
                    selected: _horario == h,
                    onSelected: (_) => setState(() => _horario = h),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivo,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ex.: conflito com o horário da escola',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _horario == null || _enviando ? null : _enviar,
                icon: const Icon(Icons.send),
                label: const Text('Enviar pedido à recepção'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoExercicioHoje extends StatelessWidget {
  const _CartaoExercicioHoje({required this.exercicio, required this.paciente});
  final Exercicio exercicio;
  final Paciente paciente;

  @override
  Widget build(BuildContext context) {
    final e = exercicio;
    return Cartao(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, color: Cores.primaria),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Exercício de Hoje da ${paciente.primeiroNome}',
                  style: TemaApp.titulo(size: 20),
                ),
              ),
              Pilula.menta('${e.duracaoMin} min'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pilula(
                'Prescrito por ${e.prescritoPorNome.replaceAll(RegExp(r' \w+$'), '')}',
                icone: Icons.verified_outlined,
              ),
              Text(
                '• ${e.categoria.isEmpty ? 'Exercícios' : e.categoria}',
                style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Bloco(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const IconeQuadrado(
                  Icons.record_voice_over,
                  fundo: Cores.menta,
                  tamanho: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.titulo, style: TemaApp.titulo(size: 16)),
                      Text(
                        e.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TemaApp.corpo(color: Cores.textoSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meta Semanal da ${paciente.primeiroNome}',
                  style: TemaApp.corpo(size: 13),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  '${e.praticasSemana} de ${e.metaSemanal} práticas realizadas '
                  '(${(e.progressoSemanal * 100).round()}%)',
                  textAlign: TextAlign.end,
                  style: TemaApp.corpo(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Cores.primaria,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BarraProgresso(e.progressoSemanal, altura: 10),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Cores.primariaContainer,
              ),
              onPressed: () => context.go(Rotas.exercicios),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Começar exercício agora'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoCobranca extends StatelessWidget {
  const _CartaoCobranca({required this.cobranca, required this.agora});
  final Cobranca cobranca;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final c = cobranca;
    final atrasada = c.situacao(agora) == SituacaoCobranca.atrasada;
    final dias = -c.diasDeAtraso(agora);
    final prazo = atrasada
        ? 'Em atraso há ${-dias} ${-dias == 1 ? 'dia' : 'dias'}'
        : dias == 0
        ? 'Vence hoje'
        : 'Vence em $dias ${dias == 1 ? 'dia' : 'dias'}';
    final titulo =
        c.descricao.startsWith('Plano') || c.descricao.contains('Mensal')
        ? 'Mensalidade ${Formatos.capitalizar(Formatos.mesCurto(c.vencimento))}'
        : c.descricao;
    return Cartao(
      child: Row(
        children: [
          const IconeQuadrado(
            Icons.receipt_long,
            fundo: Cores.erroFundo,
            cor: Cores.erroForte,
            tamanho: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TemaApp.titulo(size: 16)),
                Text(
                  '${atrasada ? 'Atrasada' : 'Pendente'} • $prazo',
                  style: TemaApp.corpo(
                    size: 13,
                    color: Cores.erroForte,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  Formatos.moeda(c.valor),
                  style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
                ),
              ],
            ),
          ),
          BotaoCinza(
            rotulo: 'Pagar PIX',
            icone: Icons.qr_code_2,
            cor: Cores.secundaria,
            corTexto: Colors.white,
            onPressed: () => _pix(context),
          ),
        ],
      ),
    );
  }

  void _pix(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagamento via PIX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Cores.containerBaixo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2, size: 120),
            ),
            const SizedBox(height: 12),
            Text(
              Formatos.moeda(cobranca.valor),
              style: TemaApp.titulo(size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'QR Code ilustrativo: a integração com banco/PIX é simulada nesta '
              'versão. A recepção dá baixa quando o pagamento é confirmado.',
              textAlign: TextAlign.center,
              style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              avisarSimulado(context, 'Código PIX copiado');
            },
            child: const Text('Copiar código'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
