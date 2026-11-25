import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'estado/sessao.dart';
import 'modelos/usuario.dart';
import 'telas/auth/cadastro_tela.dart';
import 'telas/auth/carregando_tela.dart';
import 'telas/auth/login_tela.dart';
import 'telas/casca.dart';
import 'telas/cliente/exercicios_tela.dart';
import 'telas/cliente/inicio_cliente_tela.dart';
import 'telas/demo/seletor_perfis_tela.dart';
import 'telas/dono/equipe_tela.dart';
import 'telas/dono/financeiro_tela.dart';
import 'telas/dono/visao_geral_tela.dart';
import 'telas/equipe/agenda_tela.dart';
import 'telas/equipe/reagendamento_tela.dart';
import 'telas/fono/atendimento_tela.dart';
import 'telas/fono/prescricao_tela.dart';

/// Caminhos de todas as telas.
abstract final class Rotas {
  static const entrar = '/entrar';
  static const cadastro = '/cadastro';
  static const carregando = '/carregando';
  static const perfis = '/perfis';

  static const cliente = '/cliente';
  static const exercicios = '/cliente/exercicios';

  static const agenda = '/agenda';
  static String solicitacao(String id) => '/agenda/solicitacao/$id';
  static String atendimento(String id) => '/atendimento/$id';
  static String prescrever(String id) => '/atendimento/$id/prescrever';

  static const visaoGeral = '/visao-geral';
  static const financeiro = '/financeiro';
  static const equipe = '/equipe';

  /// Tela inicial de cada perfil.
  static String inicio(Usuario u) => switch (u.perfil) {
    Perfil.cliente => cliente,
    Perfil.recepcao || Perfil.fono => agenda,
    Perfil.dono => visaoGeral,
  };

  /// Controle de acesso por perfil e permissões.
  static bool podeAcessar(Usuario u, String caminho) {
    if (caminho == perfis) return true;
    if (caminho.startsWith(cliente)) return u.perfil == Perfil.cliente;
    if (caminho.startsWith('/atendimento')) {
      return u.perfil != Perfil.cliente && u.permissoes.clinico && u.temCrfa;
    }
    if (caminho.startsWith(agenda)) {
      return u.perfil != Perfil.cliente && u.permissoes.agenda;
    }
    if (caminho == financeiro) {
      return u.perfil == Perfil.dono ||
          u.permissoes.financeiro ||
          u.permissoes.cobranca;
    }
    if (caminho == visaoGeral || caminho == equipe) {
      return u.perfil == Perfil.dono;
    }
    return false;
  }
}

GoRouter criarRoteador(Sessao sessao) {
  const publicas = {Rotas.entrar, Rotas.cadastro, Rotas.perfis};

  return GoRouter(
    initialLocation: Rotas.entrar,
    refreshListenable: sessao,
    redirect: (context, state) {
      final caminho = state.uri.path;
      switch (sessao.estado) {
        case EstadoSessao.carregando:
          // Seletor de perfis continua visível enquanto troca de personagem.
          if (caminho == Rotas.perfis) return null;
          return caminho == Rotas.carregando ? null : Rotas.carregando;
        case EstadoSessao.deslogado:
          return publicas.contains(caminho) ? null : Rotas.entrar;
        case EstadoSessao.logado:
          final u = sessao.usuario!;
          if (caminho == Rotas.entrar ||
              caminho == Rotas.cadastro ||
              caminho == Rotas.carregando) {
            return Rotas.inicio(u);
          }
          return Rotas.podeAcessar(u, caminho) ? null : Rotas.inicio(u);
      }
    },
    routes: [
      GoRoute(
        path: Rotas.carregando,
        builder: (_, _) => const CarregandoTela(),
      ),
      GoRoute(path: Rotas.entrar, builder: (_, _) => const LoginTela()),
      GoRoute(path: Rotas.cadastro, builder: (_, _) => const CadastroTela()),
      GoRoute(path: Rotas.perfis, builder: (_, _) => const SeletorPerfisTela()),
      ShellRoute(
        builder: (context, state, child) =>
            Casca(caminho: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Rotas.cliente,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: InicioClienteTela()),
            routes: [
              GoRoute(
                path: 'exercicios',
                pageBuilder: (_, _) =>
                    const NoTransitionPage(child: ExerciciosTela()),
              ),
            ],
          ),
          GoRoute(
            path: Rotas.agenda,
            pageBuilder: (_, _) => const NoTransitionPage(child: AgendaTela()),
            routes: [
              GoRoute(
                path: 'solicitacao/:id',
                builder: (_, s) =>
                    ReagendamentoTela(solicitacaoId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/atendimento/:id',
            builder: (_, s) =>
                AtendimentoTela(agendamentoId: s.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'prescrever',
                builder: (_, s) =>
                    PrescricaoTela(agendamentoId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: Rotas.visaoGeral,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: VisaoGeralTela()),
          ),
          GoRoute(
            path: Rotas.financeiro,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: FinanceiroTela()),
          ),
          GoRoute(
            path: Rotas.equipe,
            pageBuilder: (_, _) => const NoTransitionPage(child: EquipeTela()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Página não encontrada: ${state.uri.path}')),
    ),
  );
}
