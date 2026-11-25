import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/formatos.dart';
import '../../core/tema.dart';
import '../../dados/clinica_repositorio.dart';
import '../../dados/dados_demo.dart';
import '../../estado/sessao.dart';
import '../../logica/agenda_logica.dart';
import '../../logica/indicadores.dart';
import '../../modelos/agendamento.dart';
import '../../modelos/exercicio.dart';
import '../../modelos/solicitacao.dart';
import '../../rotas.dart';
import '../../widgets/comuns.dart';
import '../casca.dart';

/// Dados ao vivo exibidos nos cartões do seletor.
class _Resumo {
  _Resumo(this.agendamentos, this.exercicios, this.solicitacoes);
  final List<Agendamento> agendamentos;
  final List<Exercicio> exercicios;
  final List<SolicitacaoReagendamento> solicitacoes;
}

/// "Vocalis – Demonstração": escolha de personagem (tela do Stitch).
class SeletorPerfisTela extends StatefulWidget {
  const SeletorPerfisTela({super.key});

  @override
  State<SeletorPerfisTela> createState() => _SeletorPerfisTelaState();
}

class _SeletorPerfisTelaState extends State<SeletorPerfisTela> {
  late final Future<ClinicaRepositorio> _repo = context
      .read<Sessao>()
      .repoDemonstracao();
  String? _entrando;

  Future<void> _entrar(String uid) async {
    setState(() => _entrando = uid);
    final u = await context.read<Sessao>().entrarNaDemonstracao(uid);
    if (mounted) context.go(Rotas.inicio(u));
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<Sessao>();
    final logado = sessao.estado == EstadoSessao.logado;
    return Scaffold(
      appBar: AppBar(
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
                children: [
                  Row(
                    children: [
                      Text('Vocalis', style: TemaApp.titulo(size: 18)),
                      const SizedBox(width: 6),
                      const Pilula.lilas('Clínica'),
                    ],
                  ),
                  Text(
                    'Demonstração',
                    style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: logado ? 'Voltar ao portal' : 'Ir para o login',
            icon: Icon(logado ? Icons.close : Icons.login),
            onPressed: () => context.go(
              logado ? Rotas.inicio(sessao.usuario!) : Rotas.entrar,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<ClinicaRepositorio>(
        future: _repo,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final repo = snap.data!;
          return Observar<_Resumo>(
            stream: () => Rx.combineLatest3(
              repo.agendamentos(),
              repo.exerciciosDoPaciente('p-maite'),
              repo.solicitacoes(),
              _Resumo.new,
            ),
            builder: (context, r) => _conteudo(context, r),
          );
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context, _Resumo r) {
    final agora = DateTime.now();
    final proximaMaite = AgendaLogica.proxima(
      r.agendamentos.where((a) => a.pacienteId == 'p-maite').toList(),
      agora,
    );
    final treinos = r.exercicios.where((e) => !e.concluido).length;
    final ind = IndicadoresClinica.calcular(
      agendamentos: r.agendamentos,
      cobrancas: const [],
      numeroProfissionais: 3,
      agora: agora,
    );
    final pendente = r.solicitacoes.where((s) => s.pendente).firstOrNull;

    return Conteudo(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Pilula.lilas(
            'MODO DEMONSTRAÇÃO',
            icone: Icons.verified_outlined,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Escolha um perfil',
          style: TemaApp.titulo(size: 28, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Todos os perfis usam os mesmos dados: o que um faz aparece '
          'para os outros.',
          style: TemaApp.corpo(size: 15, color: Cores.textoSuave),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------- Cliente
        Cartao(
          faixa: Cores.primaria,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconeQuadrado(
                    Icons.sentiment_satisfied_alt,
                    fundo: Cores.menta,
                    tamanho: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cliente / Responsável',
                          style: TemaApp.titulo(size: 20),
                        ),
                        Text(
                          'Paciente: Maitê Silva, 6 anos',
                          style: TemaApp.corpo(
                            color: Cores.primaria,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Pilula('Infantil', ponto: true),
                ],
              ),
              const SizedBox(height: 12),
              Bloco(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.psychology_outlined,
                      size: 20,
                      color: Cores.textoSuave,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A mãe da Maitê vê a próxima consulta, pede troca de horário, '
                        'faz os exercícios em casa e vê as mensalidades.',
                        style: TemaApp.corpo(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: Cores.textoSuave,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      proximaMaite == null
                          ? 'Sem sessão marcada'
                          : '${Formatos.diaSemanaCurto(proximaMaite.inicio)}, '
                                '${Formatos.hora(proximaMaite.inicio)} (Presencial)',
                      style: TemaApp.corpo(size: 13, color: Cores.textoSuave),
                    ),
                  ),
                  const Icon(
                    Icons.notifications_none,
                    size: 16,
                    color: Cores.primaria,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$treinos ${treinos == 1 ? 'treino pendente' : 'treinos pendentes'}',
                    style: TemaApp.corpo(
                      size: 13,
                      color: Cores.primaria,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BotaoEntrar(
                rotulo: 'Entrar como cliente',
                icone: Icons.family_restroom,
                carregando: _entrando == ContasDemo.juliana,
                onPressed: () => _entrar(ContasDemo.juliana),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ----------------------------------------------------------- Equipe
        Cartao(
          faixa: Cores.secundaria,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconeQuadrado(
                    Icons.medical_services_outlined,
                    fundo: Cores.secundariaContainer,
                    cor: Cores.ardosia,
                    tamanho: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Equipe', style: TemaApp.titulo(size: 20)),
                        Text(
                          'Recepção e fonoaudiologia',
                          style: TemaApp.corpo(
                            size: 13,
                            color: Cores.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Bloco(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.desk_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Camila Rocha (Recepção)',
                            style: TemaApp.corpo(weight: FontWeight.w600),
                          ),
                        ),
                        const Pilula('Balcão'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cuida da agenda, confirma presenças e responde aos '
                      'pedidos de troca de horário.'
                      '${pendente != null ? ' Tem 1 troca esperando.' : ''}',
                      style: TemaApp.corpo(color: Cores.textoSuave),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: BotaoCinza(
                        rotulo: 'Entrar como recepção',
                        icone: Icons.support_agent,
                        cor: Cores.containerAlto,
                        onPressed: _entrando != null
                            ? null
                            : () => _entrar(ContasDemo.camila),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Bloco(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dra. Ana Costa',
                            style: TemaApp.corpo(weight: FontWeight.w600),
                          ),
                        ),
                        const Pilula.menta('CRFa 2-19402'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Atende, escreve a evolução (SOAP) e passa exercícios '
                      'para fazer em casa.',
                      style: TemaApp.corpo(color: Cores.textoSuave),
                    ),
                    const SizedBox(height: 10),
                    _BotaoEntrar(
                      rotulo: 'Entrar como fono',
                      icone: Icons.medical_services_outlined,
                      carregando: _entrando == ContasDemo.ana,
                      onPressed: () => _entrar(ContasDemo.ana),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ------------------------------------------------------------- Dono
        Cartao(
          faixa: Cores.primaria,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconeQuadrado(
                    Icons.apartment,
                    fundo: Cores.container,
                    cor: Cores.ardosia,
                    tamanho: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dona', style: TemaApp.titulo(size: 20)),
                        Text(
                          'Dra. Kariny Mylena, diretora',
                          style: TemaApp.corpo(
                            color: Cores.primaria,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Pilula('Admin', icone: Icons.tune),
                ],
              ),
              const SizedBox(height: 12),
              Bloco(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.insights, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vê os números do dia, as faltas, o que falta receber e '
                        'as permissões da equipe.',
                        style: TemaApp.corpo(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetrica(
                      rotulo: 'Atendimentos hoje',
                      valor: '${ind.sessoesHoje} pacientes',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniMetrica(
                      rotulo: 'Ocupação',
                      valor: '${(ind.ocupacao * 100).toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BotaoEntrar(
                rotulo: 'Entrar como dona',
                icone: Icons.bar_chart,
                carregando: _entrando == ContasDemo.kariny,
                onPressed: () => _entrar(ContasDemo.kariny),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ------------------------------------------------ Cenário interligado
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Cores.containerBaixo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_alt, color: Cores.primaria),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Teste rápido',
                      style: TemaApp.titulo(size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Para ver os perfis conversando entre si:',
                style: TemaApp.corpo(color: Cores.textoSuave),
              ),
              const SizedBox(height: 12),
              Cartao(
                child: Column(
                  children: [
                    _Passo(
                      1,
                      proximaMaite == null
                          ? 'Maitê Silva está em acompanhamento com a Dra. Ana Costa.'
                          : 'Maitê Silva tem consulta agendada para '
                                '${Formatos.diaHoraCurto(proximaMaite.inicio)} '
                                'com a Dra. Ana Costa.',
                    ),
                    _Passo(
                      2,
                      pendente != null
                          ? 'A responsável já solicitou mudança para '
                                '${Formatos.diaHoraCurto(pendente.horarioPretendido)}.'
                          : 'A mãe pede para mudar o horário pelo app.',
                    ),
                    const _Passo(
                      3,
                      'A Camila, da recepção, confirma o novo horário.',
                    ),
                    const SizedBox(height: 8),
                    Bloco(
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Cores.primaria),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'O novo horário aparece na hora para a família, na '
                              'agenda e no painel do dono.',
                              style: TemaApp.corpo(
                                size: 13,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'O botão ⇄ no topo volta para esta tela.',
                style: TemaApp.corpo(size: 12, color: Cores.textoSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotaoEntrar extends StatelessWidget {
  const _BotaoEntrar({
    required this.rotulo,
    required this.icone,
    required this.onPressed,
    this.carregando = false,
  });
  final String rotulo;
  final IconData icone;
  final VoidCallback onPressed;
  final bool carregando;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: carregando ? null : onPressed,
      icon: carregando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icone),
      label: Text(rotulo),
    ),
  );
}

class _MiniMetrica extends StatelessWidget {
  const _MiniMetrica({required this.rotulo, required this.valor});
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Bloco(
    cor: Cores.container,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: TemaApp.corpo(size: 12, color: Cores.textoSuave)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            valor,
            style: TemaApp.titulo(size: 22, color: Cores.primaria),
          ),
        ),
      ],
    ),
  );
}

class _Passo extends StatelessWidget {
  const _Passo(this.numero, this.texto);
  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Cores.menta,
          child: Text(
            '$numero',
            style: TemaApp.corpo(
              size: 12,
              weight: FontWeight.w700,
              color: Cores.primaria,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TemaApp.corpo())),
      ],
    ),
  );
}
