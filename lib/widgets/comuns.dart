import 'dart:async';

import 'package:flutter/material.dart';

import '../core/formatos.dart';
import '../core/perf.dart';
import '../core/tema.dart';
import '../modelos/agendamento.dart';

class Cartao extends StatelessWidget {
  const Cartao({
    super.key,
    required this.child,
    this.faixa,
    this.padding = const EdgeInsets.all(16),
    this.cor = Cores.superficie,
    this.raio = 16,
    this.elevado = false,
    this.onTap,
    this.borda,
  });

  final Widget child;
  final Color? faixa;
  final EdgeInsetsGeometry padding;
  final Color cor;
  final double raio;
  final bool elevado;
  final VoidCallback? onTap;
  final Color? borda;

  @override
  Widget build(BuildContext context) {
    final raioBorda = BorderRadius.circular(raio);
    return Container(
      decoration: BoxDecoration(
        color: cor,
        borderRadius: raioBorda,
        border: Border.all(color: borda ?? Cores.borda),
        boxShadow: elevado ? Sombras.nivel2 : Sombras.nivel1,
      ),
      child: ClipRRect(
        borderRadius: raioBorda,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: faixa == null
                  ? null
                  : BoxDecoration(
                      border: Border(left: BorderSide(color: faixa!, width: 5)),
                    ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class Bloco extends StatelessWidget {
  const Bloco({
    super.key,
    required this.child,
    this.cor = Cores.containerBaixo,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final Color cor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: cor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class Pilula extends StatelessWidget {
  const Pilula(
    this.texto, {
    super.key,
    this.fundo = Cores.container,
    this.cor = Cores.textoSuave,
    this.icone,
    this.ponto = false,
    this.tamanho = 12,
  });

  final String texto;
  final Color fundo;
  final Color cor;
  final IconData? icone;
  final bool ponto;
  final double tamanho;

  const Pilula.sucesso(this.texto, {super.key, this.icone, this.ponto = false})
    : fundo = Cores.sucessoFundo,
      cor = Cores.sucessoTexto,
      tamanho = 12;
  const Pilula.alerta(this.texto, {super.key, this.icone, this.ponto = false})
    : fundo = Cores.alertaFundo,
      cor = Cores.alertaTexto,
      tamanho = 12;
  const Pilula.erro(this.texto, {super.key, this.icone, this.ponto = false})
    : fundo = Cores.erroFundo,
      cor = Cores.erroTexto,
      tamanho = 12;
  const Pilula.menta(this.texto, {super.key, this.icone, this.ponto = false})
    : fundo = Cores.menta,
      cor = Cores.primaria,
      tamanho = 12;
  const Pilula.lilas(this.texto, {super.key, this.icone, this.ponto = false})
    : fundo = Cores.secundariaContainer,
      cor = Cores.ardosia,
      tamanho = 12;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ponto) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        if (icone != null) ...[
          Icon(icone, size: tamanho + 2, color: cor),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TemaApp.corpo(
              size: tamanho,
              weight: FontWeight.w600,
              color: cor,
            ),
          ),
        ),
      ],
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar(
    this.nome, {
    super.key,
    this.tamanho = 44,
    this.fundo,
    this.cor = Cores.primaria,
    this.indicador,
  });

  final String nome;
  final double tamanho;
  final Color? fundo;
  final Color cor;

  // bolinha no canto (online)
  final Color? indicador;

  static const _paleta = [
    Color(0xFFB2F1E8),
    Color(0xFFDAE2FD),
    Color(0xFFE0E3E5),
    Color(0xFFFDE7C8),
    Color(0xFFF9D9E3),
  ];

  @override
  Widget build(BuildContext context) {
    final bg = fundo ?? _paleta[nome.hashCode.abs() % _paleta.length];
    return SizedBox(
      width: tamanho,
      height: tamanho,
      child: Stack(
        children: [
          Container(
            width: tamanho,
            height: tamanho,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Text(
              Formatos.iniciais(nome),
              style: TemaApp.titulo(
                size: tamanho * 0.36,
                weight: FontWeight.w700,
                color: cor,
              ),
            ),
          ),
          if (indicador != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: tamanho * 0.28,
                height: tamanho * 0.28,
                decoration: BoxDecoration(
                  color: indicador,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class IconeQuadrado extends StatelessWidget {
  const IconeQuadrado(
    this.icone, {
    super.key,
    this.fundo = Cores.mentaSuave,
    this.cor = Cores.primaria,
    this.tamanho = 40,
  });
  final IconData icone;
  final Color fundo;
  final Color cor;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(tamanho * 0.28),
    ),
    child: Icon(icone, color: cor, size: tamanho * 0.55),
  );
}

class Sobrelinha extends StatelessWidget {
  const Sobrelinha(this.texto, {super.key, this.cor = Cores.textoSuave});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Text(
    texto.toUpperCase(),
    style: TemaApp.corpo(
      size: 12,
      weight: FontWeight.w700,
      color: cor,
      letterSpacing: 0.8,
    ),
  );
}

class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.icone, this.acao});
  final String texto;
  final IconData? icone;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        if (icone != null) ...[
          Icon(icone, color: Cores.primaria, size: 22),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(texto, style: TemaApp.titulo(size: 20))),
        ?acao,
      ],
    ),
  );
}

class BarraProgresso extends StatelessWidget {
  const BarraProgresso(
    this.valor, {
    super.key,
    this.cor = Cores.primaria,
    this.fundo = Cores.containerAlto,
    this.altura = 8,
  });
  final double valor;
  final Color cor;
  final Color fundo;
  final double altura;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
    child: LinearProgressIndicator(
      value: valor.clamp(0, 1),
      minHeight: altura,
      color: cor,
      backgroundColor: fundo,
    ),
  );
}

class BotaoCinza extends StatelessWidget {
  const BotaoCinza({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.icone,
    this.cor = Cores.container,
    this.corTexto = Cores.texto,
  });
  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final Color cor;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    final estilo = FilledButton.styleFrom(
      backgroundColor: cor,
      foregroundColor: corTexto,
      minimumSize: const Size(48, 46),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: TemaApp.corpo(size: 14, weight: FontWeight.w600),
    );
    return icone == null
        ? FilledButton(
            style: estilo,
            onPressed: onPressed,
            child: Text(rotulo, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            style: estilo,
            onPressed: onPressed,
            icon: Icon(icone, size: 18),
            label: Text(rotulo, textAlign: TextAlign.center),
          );
  }
}

// Segura a assinatura do stream entre rebuilds e só refaz quando a chave
// muda. Sem isso a tela piscava e abria listener duplicado no Firestore.
class Observar<T> extends StatefulWidget {
  const Observar({
    super.key,
    required this.stream,
    required this.builder,
    this.chave,
    this.carregando,
  });

  final Stream<T> Function() stream;
  final Widget Function(BuildContext context, T dados) builder;
  final Object? chave;
  final Widget? carregando;

  @override
  State<Observar<T>> createState() => _ObservarState<T>();
}

class _ObservarState<T> extends State<Observar<T>> {
  late Stream<T> _stream = widget.stream();

  @override
  void didUpdateWidget(covariant Observar<T> old) {
    super.didUpdateWidget(old);
    if (old.chave != widget.chave) _stream = widget.stream();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _stream,
    builder: (context, snap) {
      if (snap.hasError) {
        return EstadoVazio(
          icone: Icons.cloud_off,
          titulo: 'Não foi possível carregar',
          texto: '${snap.error}',
        );
      }
      if (!snap.hasData) {
        return widget.carregando ??
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
      }
      return widget.builder(context, snap.data as T);
    },
  );
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.texto,
  });
  final IconData icone;
  final String titulo;
  final String? texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icone, size: 40, color: Cores.contornoSuave),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: TemaApp.titulo(size: 16, weight: FontWeight.w600),
        ),
        if (texto != null) ...[
          const SizedBox(height: 4),
          Text(
            texto!,
            textAlign: TextAlign.center,
            style: TemaApp.corpo(color: Cores.textoSuave),
          ),
        ],
      ],
    ),
  );
}

// WhatsApp, PIX, NF-e, gravação etc. ainda não estão integrados
void avisarSimulado(BuildContext context, String acao) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$acao: recurso simulado na demonstração.'),
        duration: const Duration(seconds: 3),
      ),
    );
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

({Color fundo, Color texto, Color faixa, IconData icone}) estiloStatus(
  StatusAgendamento s,
) => switch (s) {
  StatusAgendamento.agendado => (
    fundo: Cores.container,
    texto: Cores.textoSuave,
    faixa: Cores.contornoSuave,
    icone: Icons.event,
  ),
  StatusAgendamento.confirmado => (
    fundo: Cores.sucessoFundo,
    texto: Cores.sucessoTexto,
    faixa: Cores.sucesso,
    icone: Icons.check_circle_outline,
  ),
  StatusAgendamento.naRecepcao => (
    fundo: Cores.menta,
    texto: Cores.primaria,
    faixa: Cores.primaria,
    icone: Icons.how_to_reg,
  ),
  StatusAgendamento.emAtendimento => (
    fundo: Cores.secundariaContainer,
    texto: Cores.ardosia,
    faixa: Cores.secundaria,
    icone: Icons.circle,
  ),
  StatusAgendamento.concluido => (
    fundo: Cores.sucessoFundo,
    texto: Cores.sucessoTexto,
    faixa: Cores.primaria,
    icone: Icons.done_all,
  ),
  StatusAgendamento.faltou => (
    fundo: Cores.erroFundo,
    texto: Cores.erroTexto,
    faixa: Cores.erro,
    icone: Icons.person_off_outlined,
  ),
  StatusAgendamento.cancelado => (
    fundo: Cores.erroFundo,
    texto: Cores.erroTexto,
    faixa: Cores.erro,
    icone: Icons.cancel_outlined,
  ),
};

class Relogio extends StatefulWidget {
  const Relogio({super.key, required this.builder, this.intervalo = 1});
  final Widget Function(BuildContext context, DateTime agora) builder;
  final int intervalo;

  @override
  State<Relogio> createState() => _RelogioState();
}

class _RelogioState extends State<Relogio> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      Duration(seconds: widget.intervalo),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

// largura máx. 720 pra não esticar na web
class Conteudo extends StatelessWidget {
  const Conteudo({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

// Igual o Conteudo, mas a lista é lazy (SliverList.builder).
// Com 5.000 itens o Conteudo montava os 5.000 de uma vez.
class ConteudoLista extends StatelessWidget {
  const ConteudoLista({
    super.key,
    required this.cabecalho,
    required this.quantidade,
    required this.item,
    this.rodape = const [],
    this.espaco = 10,
  });

  final List<Widget> cabecalho;
  final int quantidade;
  final Widget Function(BuildContext context, int indice) item;
  final List<Widget> rodape;

  final double espaco;

  @override
  Widget build(BuildContext context) {
    Widget coluna(List<Widget> filhos) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filhos,
    );
    return LayoutBuilder(
      builder: (context, c) {
        // mesma largura do Conteudo
        final lateral = c.maxWidth > 752 ? (c.maxWidth - 720) / 2 : 16.0;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(lateral, 8, lateral, 0),
              sliver: SliverToBoxAdapter(child: coluna(cabecalho)),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: lateral),
              sliver: SliverList.builder(
                itemCount: quantidade,
                itemBuilder: (context, i) => Padding(
                  padding: EdgeInsets.only(bottom: espaco),
                  child: item(context, i),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(lateral, 0, lateral, 32),
              sliver: SliverToBoxAdapter(child: coluna(rodape)),
            ),
          ],
        );
      },
    );
  }
}

// Faz o cálculo pesado fora do build:
// - só recalcula se a entrada mudar (==)
// - roda no Isolate
// - mostra o resultado anterior enquanto não termina
// Com Perf.otimizado = false calcula no build mesmo, como era antes.
// calcular tem que ser top-level ou static.
class Calculado<E, R> extends StatefulWidget {
  const Calculado({
    super.key,
    required this.entrada,
    required this.calcular,
    required this.builder,
    this.rotulo,
  });

  final E entrada;
  final R Function(E entrada) calcular;
  final Widget Function(BuildContext context, R resultado) builder;
  final String? rotulo;

  @override
  State<Calculado<E, R>> createState() => _CalculadoState<E, R>();
}

class _CalculadoState<E, R> extends State<Calculado<E, R>> {
  R? _resultado;
  bool _temResultado = false;
  int _geracao = 0;

  @override
  void initState() {
    super.initState();
    if (Perf.otimizado) _recalcular();
  }

  @override
  void didUpdateWidget(covariant Calculado<E, R> old) {
    super.didUpdateWidget(old);
    if (Perf.otimizado && old.entrada != widget.entrada) _recalcular();
  }

  Future<void> _recalcular() async {
    final geracao = ++_geracao;
    final r = await calcularForaDaUI(
      widget.calcular,
      widget.entrada,
      rotulo: widget.rotulo,
    );
    // a entrada mudou no meio, joga fora
    if (!mounted || geracao != _geracao) return;
    setState(() {
      _resultado = r;
      _temResultado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Perf.otimizado) {
      return widget.builder(context, widget.calcular(widget.entrada));
    }
    if (!_temResultado) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return widget.builder(context, _resultado as R);
  }
}
