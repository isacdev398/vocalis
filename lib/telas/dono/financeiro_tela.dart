import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatos.dart';
import '../../core/perf.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../logica/resumo_financeiro.dart';
import '../../modelos/cobranca.dart';
import '../../widgets/comuns.dart';

enum _Filtro {
  todos('Todos'),
  recebidos('Recebidos'),
  pendentes('Pendentes'),
  atrasados('Em atraso');

  const _Filtro(this.rotulo);
  final String rotulo;
}

typedef _EntradaResumo = ({List<Cobranca> todas, DateTime mes, DateTime hoje});

// top-level por causa do Isolate
ResumoFinanceiro _calcularResumo(_EntradaResumo e) =>
    ResumoFinanceiro.calcular(e.todas, mes: e.mes, hoje: e.hoje);

class FinanceiroTela extends StatefulWidget {
  const FinanceiroTela({super.key});

  @override
  State<FinanceiroTela> createState() => _FinanceiroTelaState();
}

class _FinanceiroTelaState extends State<FinanceiroTela> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  _Filtro _filtro = _Filtro.todos;
  String _busca = '';
  bool _mostrarBusca = false;
  Timer? _debounceBusca;

  void _mudarMes(int delta) => setState(() {
    _mes = DateTime(_mes.year, _mes.month + delta);
  });

  // debounce de 250 ms na busca
  void _aoDigitar(String v) {
    if (!Perf.otimizado) {
      setState(() => _busca = v);
      return;
    }
    _debounceBusca?.cancel();
    _debounceBusca = Timer(
      const Duration(milliseconds: 250),
      () => setState(() => _busca = v),
    );
  }

  @override
  void dispose() {
    _debounceBusca?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ClinicaRepositorio>();
    return Observar<List<Cobranca>>(
      chave: repo,
      stream: repo.cobrancas,
      builder: (context, todas) {
        final agora = DateTime.now();
        return Calculado<_EntradaResumo, ResumoFinanceiro>(
          entrada: (
            todas: todas,
            mes: _mes,
            hoje: DateTime(agora.year, agora.month, agora.day),
          ),
          calcular: _calcularResumo,
          rotulo: 'resumo financeiro',
          builder: (context, r) => _pagina(context, r, agora),
        );
      },
    );
  }

  Widget _pagina(BuildContext context, ResumoFinanceiro r, DateTime hoje) {
    int contar(_Filtro f) => _filtrar(r.lancamentos, f, hoje).length;
    final lista = _filtrar(r.lancamentos, _filtro, hoje)
        .where(
          (c) =>
              _busca.isEmpty ||
              '${c.pacienteNome} ${c.responsavelNome}'.toLowerCase().contains(
                _busca.toLowerCase(),
              ),
        )
        .toList();

    final cabecalho = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Financeiro',
              style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
      Text(
        'Mensalidades e sessões avulsas',
        style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Cores.containerBaixo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: () => _mudarMes(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Cores.primaria,
                  ),
                  const SizedBox(width: 8),
                  Text(Formatos.mesAno(_mes), style: TemaApp.titulo(size: 18)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: () => _mudarMes(1),
              icon: const Icon(Icons.chevron_right),
            ),
            BotaoCinza(
              rotulo: 'Filtros',
              icone: Icons.tune,
              cor: Colors.white,
              onPressed: () => setState(() => _mostrarBusca = !_mostrarBusca),
            ),
          ],
        ),
      ),
      if (_mostrarBusca) ...[
        const SizedBox(height: 10),
        TextField(
          autofocus: true,
          onChanged: _aoDigitar,
          decoration: const InputDecoration(
            hintText: 'Filtrar por paciente ou responsável',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ],
      const SizedBox(height: 14),
      _CartaoRecebido(r: r),
      const SizedBox(height: 12),
      _CartaoAReceber(r: r),
      const SizedBox(height: 12),
      _CartaoMix(r: r),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: BotaoCinza(
              rotulo: 'Exportar relatório',
              icone: Icons.download_outlined,
              onPressed: () =>
                  avisarSimulado(context, 'Exportação de relatório'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BotaoCinza(
              rotulo: 'Emitir notas fiscais',
              icone: Icons.receipt_long_outlined,
              cor: Cores.secundariaContainer,
              onPressed: () => avisarSimulado(context, 'Emissão de NF-e'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text(
              'Mensalidades e sessões',
              style: TemaApp.titulo(size: 20),
            ),
          ),
          Text(
            '${r.lancamentos.length} lançamentos',
            style: TemaApp.corpo(size: 12),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _Filtro.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text('${f.rotulo} (${contar(f)})'),
                  selected: _filtro == f,
                  selectedColor: Cores.primaria,
                  labelStyle: TemaApp.corpo(
                    weight: FontWeight.w600,
                    color: _filtro == f ? Colors.white : Cores.texto,
                  ),
                  onSelected: (_) => setState(() => _filtro = f),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (lista.isEmpty)
        const EstadoVazio(
          icone: Icons.receipt_outlined,
          titulo: 'Nenhum lançamento neste filtro',
        ),
    ];
    final rodape = <Widget>[
      const SizedBox(height: 12),
      Bloco(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conciliação bancária',
                    style: TemaApp.corpo(weight: FontWeight.w700),
                  ),
                  Text(
                    'Integração com banco simulada nesta versão.',
                    style: TemaApp.corpo(size: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: () => avisarSimulado(context, 'Conciliação bancária'),
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
      ),
    ];

    if (Perf.otimizado) {
      return ConteudoLista(
        cabecalho: cabecalho,
        quantidade: lista.length,
        item: (_, i) => _CartaoLancamento(cobranca: lista[i], hoje: hoje),
        rodape: rodape,
      );
    }
    // versão antiga: tudo numa Column
    return Conteudo(
      children: [
        ...cabecalho,
        for (final c in lista) ...[
          _CartaoLancamento(cobranca: c, hoje: hoje),
          const SizedBox(height: 10),
        ],
        ...rodape,
      ],
    );
  }

  List<Cobranca> _filtrar(
    List<Cobranca> l,
    _Filtro f,
    DateTime hoje,
  ) => switch (f) {
    _Filtro.todos => l,
    _Filtro.recebidos => l.where((c) => c.paga).toList(),
    _Filtro.pendentes =>
      l.where((c) => c.situacao(hoje) == SituacaoCobranca.pendente).toList(),
    _Filtro.atrasados =>
      l.where((c) => c.situacao(hoje) == SituacaoCobranca.atrasada).toList(),
  };
}

class _CartaoRecebido extends StatelessWidget {
  const _CartaoRecebido({required this.r});
  final ResumoFinanceiro r;

  @override
  Widget build(BuildContext context) {
    final (inteiro, centavos) = Formatos.moedaPartes(r.recebido);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Cores.primaria,
        borderRadius: BorderRadius.circular(18),
        boxShadow: Sombras.nivel2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeQuadrado(
                Icons.account_balance_wallet_outlined,
                fundo: Color(0x33FFFFFF),
                cor: Colors.white,
                tamanho: 32,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Sobrelinha('Recebido no mês', cor: Colors.white),
              ),
              if (r.variacao != null)
                Pilula(
                  '${r.variacao! >= 0 ? '↑' : '↓'} ${(r.variacao!.abs() * 100).toStringAsFixed(1)}%',
                  fundo: Cores.menta,
                  cor: Cores.primaria,
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: inteiro,
                    style: TemaApp.titulo(size: 38, color: Colors.white),
                  ),
                  TextSpan(
                    text: centavos,
                    style: TemaApp.titulo(size: 22, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'vs ${Formatos.moeda(r.recebidoMesAnterior)} no mês anterior',
            style: TemaApp.corpo(size: 14, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cobranças pagas',
                        style: TemaApp.corpo(size: 12, color: Colors.white70),
                      ),
                      Text(
                        '${r.quantidadeBaixadas} lançamentos',
                        style: TemaApp.titulo(size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Média por cobrança',
                        style: TemaApp.corpo(size: 12, color: Colors.white70),
                      ),
                      Text(
                        Formatos.moeda(r.ticketMedio),
                        style: TemaApp.titulo(size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoAReceber extends StatelessWidget {
  const _CartaoAReceber({required this.r});
  final ResumoFinanceiro r;

  @override
  Widget build(BuildContext context) {
    final (inteiro, centavos) = Formatos.moedaPartes(r.aReceber);
    final atraso = r.fracaoAtraso;
    return Cartao(
      faixa: Cores.alerta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconeQuadrado(
                Icons.pending_actions,
                fundo: Cores.container,
                cor: Cores.texto,
                tamanho: 34,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Sobrelinha('A receber', cor: Cores.texto)),
              if (r.quantidadeAtrasadas > 0)
                Pilula.erro(
                  '${r.quantidadeAtrasadas} em atraso',
                  icone: Icons.warning_amber,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: inteiro, style: TemaApp.titulo(size: 26)),
                    TextSpan(text: centavos, style: TemaApp.titulo(size: 16)),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${r.quantidadeAbertas} faturas pendentes',
                style: TemaApp.corpo(size: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: ((1 - atraso) * 100).round().clamp(0, 100),
                    child: Container(color: Cores.alerta),
                  ),
                  Expanded(
                    flex: (atraso * 100).round().clamp(0, 100),
                    child: Container(color: Cores.erroForte),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${((1 - atraso) * 100).round()}% a vencer em dia',
                style: TemaApp.corpo(size: 12),
              ),
              const Spacer(),
              Text(
                '${(atraso * 100).round()}% inadimplência',
                style: TemaApp.corpo(size: 12, color: Cores.erroForte),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaoMix extends StatelessWidget {
  const _CartaoMix({required this.r});
  final ResumoFinanceiro r;

  static const _cores = {
    FormaPagamento.pix: Cores.primaria,
    FormaPagamento.cartao: Cores.secundaria,
    FormaPagamento.convenio: Cores.teal,
  };

  @override
  Widget build(BuildContext context) {
    final temDados = r.mix.values.any((v) => v > 0);
    return Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Formas de pagamento',
                  style: TemaApp.titulo(size: 20),
                ),
              ),
              Text(
                'Atualizado hoje',
                style: TemaApp.corpo(size: 12, color: Cores.primaria),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 10,
              child: temDados
                  ? Row(
                      children: [
                        for (final f in FormaPagamento.values)
                          if (r.mix[f]! > 0)
                            Expanded(
                              flex: (r.mix[f]! * 1000).round().clamp(1, 1000),
                              child: Container(
                                margin: const EdgeInsets.only(right: 2),
                                color: _cores[f],
                              ),
                            ),
                      ],
                    )
                  : Container(color: Cores.containerAlto),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final f in FormaPagamento.values)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _cores[f],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            f == FormaPagamento.pix ? 'PIX' : f.rotulo,
                            style: TemaApp.corpo(size: 12),
                          ),
                        ],
                      ),
                      Text(
                        '${(r.mix[f]! * 100).round()}%',
                        style: TemaApp.titulo(size: 16),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartaoLancamento extends StatelessWidget {
  const _CartaoLancamento({required this.cobranca, required this.hoje});
  final Cobranca cobranca;
  final DateTime hoje;

  Future<void> _receber(BuildContext context) async {
    final repo = context.read<ClinicaRepositorio>();
    final forma = await showDialog<FormaPagamento>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Dar baixa em ${Formatos.moeda(cobranca.valor)}'),
        children: [
          for (final f in FormaPagamento.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('Recebido via ${f.rotulo}'),
              ),
            ),
        ],
      ),
    );
    if (forma == null) return;
    await repo.registrarPagamento(cobranca.id, forma);
    if (context.mounted) {
      avisar(context, 'Pagamento de ${cobranca.pacienteNome} registrado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = cobranca;
    final repo = context.read<ClinicaRepositorio>();
    final sit = c.situacao(hoje);
    final atrasada = sit == SituacaoCobranca.atrasada;
    final faixa = switch (sit) {
      SituacaoCobranca.paga => Cores.primaria,
      SituacaoCobranca.pendente => Cores.alerta,
      SituacaoCobranca.atrasada => Cores.erroForte,
    };

    final Widget pilula = switch (sit) {
      SituacaoCobranca.paga => Pilula.sucesso(
        c.pagoEm!.mesmoDia(hoje)
            ? 'Pago via ${c.forma?.rotulo ?? '-'} às ${Formatos.hora(c.pagoEm!)}'
            : 'Pago via ${c.forma?.rotulo ?? '-'} em ${Formatos.diaMes(c.pagoEm!)}',
        icone: Icons.check_circle_outline,
      ),
      SituacaoCobranca.pendente => Pilula.alerta(
        c.avisoEnviado ? 'Aviso enviado' : 'Pendente',
        icone: Icons.schedule,
      ),
      SituacaoCobranca.atrasada => Pilula.erro(
        '${c.diasDeAtraso(hoje)} dias em atraso',
        icone: Icons.error_outline,
      ),
    };

    return Cartao(
      faixa: faixa,
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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: c.pacienteNome,
                            style: TemaApp.corpo(
                              size: 16,
                              weight: FontWeight.w700,
                              color: atrasada ? Cores.erroForte : Cores.texto,
                            ),
                          ),
                          if (c.responsavelNome.isNotEmpty)
                            TextSpan(
                              text: '  (Resp: ${c.responsavelNome})',
                              style: TemaApp.corpo(size: 12),
                            ),
                        ],
                      ),
                    ),
                    Text(c.descricao, style: TemaApp.corpo(size: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatos.moeda(c.valor),
                    style: TemaApp.titulo(
                      size: 20,
                      color: atrasada ? Cores.erroForte : Cores.texto,
                    ),
                  ),
                  Text(
                    c.vencimento.mesmoDia(hoje)
                        ? 'Hoje, ${Formatos.diaMes(c.vencimento)}'
                        : 'Venc: ${Formatos.diaMes(c.vencimento)}',
                    style: TemaApp.corpo(size: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: pilula),
              ),
              const SizedBox(width: 6),
              if (sit == SituacaoCobranca.paga)
                IconButton(
                  tooltip: 'Recibo',
                  onPressed: () => avisarSimulado(context, 'Recibo'),
                  icon: const Icon(Icons.receipt_outlined),
                )
              else ...[
                IconButton(
                  tooltip: 'Registrar pagamento',
                  style: IconButton.styleFrom(backgroundColor: Cores.container),
                  onPressed: () => _receber(context),
                  icon: const Icon(Icons.price_check),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    backgroundColor: atrasada
                        ? Cores.erroForte
                        : Cores.primaria,
                  ),
                  onPressed: () async {
                    await repo.marcarAvisoEnviado(c.id);
                    if (context.mounted) {
                      avisarSimulado(context, 'Cobrança por WhatsApp');
                    }
                  },
                  icon: Icon(
                    atrasada ? Icons.chat_outlined : Icons.send,
                    size: 18,
                  ),
                  label: Text(atrasada ? 'Notificar' : 'Cobrar'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
