import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/tema.dart';
import '../estado/sessao.dart';
import '../modelos/usuario.dart';
import '../rotas.dart';
import '../widgets/comuns.dart';

/// Uma aba da barra de navegação inferior.
class AbaNavegacao {
  const AbaNavegacao(this.rotulo, this.icone, this.iconeAtivo, this.caminho);
  final String rotulo;
  final IconData icone;
  final IconData iconeAtivo;
  final String caminho;
}

/// Estrutura comum dos portais: barra superior "Vocalis" e barra de
/// navegação inferior, cujas abas dependem do perfil logado.
class Casca extends StatelessWidget {
  const Casca({super.key, required this.caminho, required this.child});

  final String caminho;
  final Widget child;

  static List<AbaNavegacao> abasPara(Usuario u, {required bool demo}) {
    final abas = switch (u.perfil) {
      Perfil.cliente => const [
        AbaNavegacao('Início', Icons.spa_outlined, Icons.spa, Rotas.cliente),
        AbaNavegacao(
          'Exercícios',
          Icons.record_voice_over_outlined,
          Icons.record_voice_over,
          Rotas.exercicios,
        ),
      ],
      Perfil.dono => const [
        AbaNavegacao(
          'Visão Geral',
          Icons.dashboard_outlined,
          Icons.dashboard,
          Rotas.visaoGeral,
        ),
        AbaNavegacao(
          'Agenda',
          Icons.calendar_month_outlined,
          Icons.calendar_month,
          Rotas.agenda,
        ),
        AbaNavegacao(
          'Financeiro',
          Icons.payments_outlined,
          Icons.payments,
          Rotas.financeiro,
        ),
        AbaNavegacao(
          'Equipe',
          Icons.groups_outlined,
          Icons.groups,
          Rotas.equipe,
        ),
      ],
      Perfil.recepcao || Perfil.fono => [
        const AbaNavegacao(
          'Agenda',
          Icons.calendar_month_outlined,
          Icons.calendar_month,
          Rotas.agenda,
        ),
        if (Rotas.podeAcessar(u, Rotas.financeiro))
          const AbaNavegacao(
            'Financeiro',
            Icons.payments_outlined,
            Icons.payments,
            Rotas.financeiro,
          ),
      ],
    };
    return [
      ...abas,
      if (demo)
        const AbaNavegacao(
          'Perfis',
          Icons.switch_account_outlined,
          Icons.switch_account,
          Rotas.perfis,
        ),
    ];
  }

  static String subtitulo(Usuario u) => switch (u.perfil) {
    Perfil.cliente => 'Portal do Cliente',
    Perfil.recepcao => 'Recepção • ${u.nome.split(' ').first}',
    Perfil.fono => 'Área Clínica',
    Perfil.dono => u.nome,
  };

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final u = sessao.usuario;
    if (u == null) return const SizedBox.shrink();

    final abas = abasPara(u, demo: sessao.emDemonstracao);
    // A aba ativa é a de prefixo mais longo que combina com o caminho.
    var indice = -1;
    var maior = 0;
    for (var i = 0; i < abas.length; i++) {
      final c = abas[i].caminho;
      if ((caminho == c || caminho.startsWith('$c/')) && c.length > maior) {
        indice = i;
        maior = c.length;
      }
    }
    if (indice < 0 && caminho.startsWith('/atendimento')) {
      indice = abas.indexWhere((a) => a.caminho == Rotas.agenda);
    }

    return Scaffold(
      appBar: _BarraTopo(usuario: u, sessao: sessao),
      body: child,
      bottomNavigationBar: abas.length < 2
          ? null
          : NavigationBar(
              selectedIndex: indice < 0 ? 0 : indice,
              indicatorColor: indice < 0 ? Colors.transparent : null,
              onDestinationSelected: (i) => context.go(abas[i].caminho),
              destinations: [
                for (final a in abas)
                  NavigationDestination(
                    icon: Icon(a.icone),
                    selectedIcon: Icon(a.iconeAtivo),
                    label: a.rotulo,
                  ),
              ],
            ),
    );
  }
}

class _BarraTopo extends StatelessWidget implements PreferredSizeWidget {
  const _BarraTopo({required this.usuario, required this.sessao});
  final Usuario usuario;
  final Sessao sessao;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          const LogoFono(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Vocalis',
                        overflow: TextOverflow.ellipsis,
                        style: TemaApp.titulo(size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Pilula.lilas('Clínica'),
                  ],
                ),
                Text(
                  Casca.subtitulo(usuario),
                  overflow: TextOverflow.ellipsis,
                  style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (sessao.emDemonstracao)
          IconButton(
            tooltip: 'Trocar perfil',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.go(Rotas.perfis),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 4),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _abrirMenu(context),
            child: Tooltip(
              message: 'Minha conta',
              child: usuario.perfil == Perfil.dono
                  ? Avatar(
                      usuario.nome,
                      tamanho: 40,
                      fundo: Cores.primaria,
                      cor: Colors.white,
                    )
                  : const CircleAvatar(
                      radius: 20,
                      backgroundColor: Cores.primaria,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _abrirMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Cores.superficie,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(usuario.nome, tamanho: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(usuario.nome, style: TemaApp.titulo(size: 18)),
                        Text(
                          usuario.email,
                          style: TemaApp.corpo(color: Cores.textoSuave),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pilula.menta(
                    usuario.perfil.rotulo,
                    icone: usuario.perfil.icone,
                  ),
                  if (usuario.registro.isNotEmpty) Pilula(usuario.registro),
                  if (sessao.emDemonstracao)
                    const Pilula.alerta(
                      'Modo demonstração',
                      icone: Icons.science_outlined,
                    )
                  else
                    const Pilula.sucesso(
                      'Conectado ao Firebase',
                      icone: Icons.cloud_done_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (usuario.perfil == Perfil.dono && !sessao.emDemonstracao) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await sessao.popularDadosDeExemplo();
                    if (context.mounted) {
                      avisar(context, 'Dados de exemplo gravados no Firebase.');
                    }
                  },
                  icon: const Icon(Icons.dataset_outlined),
                  label: const Text('Popular dados de exemplo'),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Cores.container,
                    foregroundColor: Cores.erroForte,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    sessao.sair();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marca do app (no protótipo havia uma imagem quebrada no lugar).
class LogoFono extends StatelessWidget {
  const LogoFono({super.key, this.tamanho = 38});
  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Cores.primariaContainer, Cores.primaria],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(tamanho * 0.3),
    ),
    child: Icon(Icons.graphic_eq, color: Colors.white, size: tamanho * 0.6),
  );
}
