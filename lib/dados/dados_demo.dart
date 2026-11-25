import 'dart:math';

import '../core/formatos.dart';
import '../modelos/agendamento.dart';
import '../modelos/cobranca.dart';
import '../modelos/evolucao.dart';
import '../modelos/exercicio.dart';
import '../modelos/paciente.dart';
import '../modelos/solicitacao.dart';
import '../modelos/usuario.dart';
import 'banco_dados.dart';

/// Contas usadas no Seletor de Perfis da demonstração.
abstract final class ContasDemo {
  static const senha = 'demo123';

  static const juliana = 'demo-juliana';
  static const camila = 'demo-camila';
  static const ana = 'demo-ana';
  static const beatriz = 'demo-beatriz';
  static const marcos = 'demo-marcos';
  static const kariny = 'demo-kariny';
  static const lucasVieira = 'demo-lucas';

  static const usuarios = <Usuario>[
    Usuario(
      id: juliana,
      nome: 'Juliana Silva',
      email: 'juliana@vocalis.demo',
      perfil: Perfil.cliente,
      pacienteId: 'p-maite',
      parentesco: 'Mãe',
    ),
    Usuario(
      id: camila,
      nome: 'Camila Rocha',
      email: 'camila@vocalis.demo',
      perfil: Perfil.recepcao,
      cargo: 'Recepção / Balcão',
      especialidade: 'Recepção e triagem',
      permissoes: Permissoes(agenda: true, cadastros: true, cobranca: true),
    ),
    Usuario(
      id: ana,
      nome: 'Dra. Ana Costa',
      email: 'ana@vocalis.demo',
      perfil: Perfil.fono,
      cargo: 'Titular',
      registro: 'CRFa 2-19402',
      especialidade: 'Fono infantil e linguagem',
      permissoes: Permissoes(agenda: true, clinico: true),
    ),
    Usuario(
      id: beatriz,
      nome: 'Dra. Beatriz Lima',
      email: 'beatriz@vocalis.demo',
      perfil: Perfil.fono,
      cargo: 'Fonoaudióloga',
      registro: 'CRFa 2-18754',
      especialidade: 'Audiologia e Exames',
      permissoes: Permissoes(agenda: true, clinico: true),
    ),
    Usuario(
      id: marcos,
      nome: 'Dr. Marcos Souza',
      email: 'marcos@vocalis.demo',
      perfil: Perfil.fono,
      cargo: 'Fonoaudiólogo',
      registro: 'CRFa 2-16238',
      especialidade: 'Motricidade orofacial e voz',
      permissoes: Permissoes(agenda: true, clinico: true),
    ),
    Usuario(
      id: kariny,
      nome: 'Dra. Kariny Mylena',
      email: 'kariny@vocalis.demo',
      perfil: Perfil.dono,
      cargo: 'Diretora clínica',
      especialidade: 'Diretora clínica',
      permissoes: Permissoes(
        agenda: true,
        cadastros: true,
        cobranca: true,
        clinico: true,
        financeiro: true,
      ),
    ),
    Usuario(
      id: lucasVieira,
      nome: 'Lucas Vieira',
      email: 'lucas@vocalis.demo',
      perfil: Perfil.recepcao,
      cargo: 'Administrativo',
      especialidade: 'Financeiro',
      permissoes: Permissoes(agenda: true, financeiro: true, cobranca: true),
    ),
  ];
}

/// Grava no banco todo o cenário da demonstração.
/// Também é usado pelo botão "Popular dados de exemplo" no Firebase real.
///
/// [estresse] > 0 acrescenta essa quantidade de cobranças no mês atual e de
/// agendamentos antigos, para medir o desempenho com muitos dados
/// (ver PERFORMANCE.md).
Future<void> popularDadosDemo(
  BancoDados banco, {
  DateTime? agora,
  int estresse = 0,
}) async {
  final hoje = agora ?? DateTime.now();
  final escritor = _Escritor(banco);
  final rnd = Random(7);

  for (final u in ContasDemo.usuarios) {
    escritor.set('usuarios', u.id, u.toMap());
  }

  DateTime anosAtras(int anos, int meses) =>
      DateTime(hoje.year - anos, hoje.month - meses, 12);

  final pacientes = <Paciente>[
    Paciente(
      id: 'p-maite',
      nome: 'Maitê Silva',
      dataNascimento: anosAtras(6, 3),
      responsavelNome: 'Juliana Silva',
      parentesco: 'Mãe',
      telefone: '(11) 98765-4321',
      area: 'Fonoaudiologia Infantil (Linguagem)',
      hipotese: 'Desvio Fonológico — Plosivas e Fricativas (/s/, /z/)',
      foco: 'Fricativas',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      estrelas: 14,
    ),
    Paciente(
      id: 'p-pedro',
      nome: 'Pedro Alencar',
      dataNascimento: anosAtras(4, 5),
      responsavelNome: 'Carla Alencar',
      parentesco: 'Mãe',
      telefone: '(11) 97654-1122',
      area: 'Linguagem',
      hipotese: 'Atraso de linguagem expressiva',
      foco: 'Vocabulário',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      estrelas: 6,
    ),
    Paciente(
      id: 'p-helena',
      nome: 'Helena Prado',
      dataNascimento: anosAtras(34, 0),
      telefone: '(11) 99812-3344',
      convenio: 'Convênio Saúde+',
      area: 'Voz',
      hipotese: 'Disfonia funcional por uso vocal profissional',
      foco: 'Voz',
      profissionalId: ContasDemo.marcos,
      profissionalNome: 'Dr. Marcos Souza',
    ),
    Paciente(
      id: 'p-lucas',
      nome: 'Lucas Ferreira',
      dataNascimento: anosAtras(8, 2),
      responsavelNome: 'Rafael Ferreira',
      parentesco: 'Pai',
      telefone: '(11) 98123-7788',
      area: 'Fluência',
      hipotese: 'Gagueira do desenvolvimento',
      foco: 'Fluência',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      estrelas: 9,
    ),
    Paciente(
      id: 'p-sophia',
      nome: 'Sophia Mendes',
      dataNascimento: anosAtras(11, 1),
      responsavelNome: 'Paula Mendes',
      parentesco: 'Mãe',
      telefone: '(11) 99001-2233',
      area: 'Audiologia',
      hipotese: 'Investigação de perda auditiva condutiva',
      foco: 'Audição',
      profissionalId: ContasDemo.beatriz,
      profissionalNome: 'Dra. Beatriz Lima',
    ),
    Paciente(
      id: 'p-davi',
      nome: 'Davi Rocha',
      dataNascimento: anosAtras(7, 6),
      responsavelNome: 'Marina Rocha',
      parentesco: 'Mãe',
      telefone: '(11) 98455-6677',
      area: 'Motricidade Orofacial',
      hipotese: 'Deglutição atípica com interposição lingual',
      foco: 'Deglutição',
      profissionalId: ContasDemo.marcos,
      profissionalNome: 'Dr. Marcos Souza',
      estrelas: 4,
    ),
    Paciente(
      id: 'p-laura',
      nome: 'Laura Nunes',
      dataNascimento: anosAtras(5, 4),
      responsavelNome: 'Tiago Nunes',
      parentesco: 'Pai',
      telefone: '(11) 97300-4455',
      area: 'Linguagem',
      hipotese: 'Transtorno fonológico — omissão de líquidas',
      foco: 'Líquidas',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      estrelas: 11,
    ),
    Paciente(
      id: 'p-gabriel',
      nome: 'Gabriel Torres',
      dataNascimento: anosAtras(62, 0),
      telefone: '(11) 99555-8899',
      area: 'Audiologia',
      hipotese: 'Presbiacusia — adaptação de AASI',
      foco: 'AASI',
      profissionalId: ContasDemo.beatriz,
      profissionalNome: 'Dra. Beatriz Lima',
    ),
  ];
  final porId = {for (final p in pacientes) p.id: p};
  for (final p in pacientes) {
    escritor.set('pacientes', p.id, p.toMap());
  }

  const nomesProfissionais = {
    ContasDemo.ana: 'Dra. Ana Costa',
    ContasDemo.beatriz: 'Dra. Beatriz Lima',
    ContasDemo.marcos: 'Dr. Marcos Souza',
  };
  const salaDe = {
    ContasDemo.ana: 'Sala 02 - Lúdica',
    ContasDemo.beatriz: 'Cabine Audiometria',
    ContasDemo.marcos: 'Sala 01 - Linguagem e Fala',
  };
  const pacientesDe = {
    ContasDemo.ana: ['p-maite', 'p-pedro', 'p-lucas', 'p-laura'],
    ContasDemo.beatriz: ['p-sophia', 'p-gabriel'],
    ContasDemo.marcos: ['p-helena', 'p-davi'],
  };

  final sessoes = <String, int>{};
  var contador = 0;

  Agendamento novo(
    String pacienteId,
    String profissionalId,
    DateTime inicio, {
    StatusAgendamento status = StatusAgendamento.agendado,
    int duracao = 45,
    String tipo = 'Terapia',
    String? id,
    bool evolucaoSalva = false,
  }) {
    final p = porId[pacienteId]!;
    final numero = (sessoes[pacienteId] ?? 0) + 1;
    sessoes[pacienteId] = numero;
    return Agendamento(
      id: id ?? 'ag-${contador++}',
      pacienteId: pacienteId,
      pacienteNome: p.nome,
      pacienteNascimento: p.dataNascimento,
      profissionalId: profissionalId,
      profissionalNome: nomesProfissionais[profissionalId]!,
      sala: salaDe[profissionalId]!,
      inicio: inicio,
      fim: inicio.add(Duration(minutes: duracao)),
      tipo: tipo,
      status: status,
      sessaoNumero: numero,
      evolucaoSalva: evolucaoSalva,
    );
  }

  final agendamentos = <Agendamento>[];
  final cobrancas = <Cobranca>[];
  const mensalistas = {'p-maite', 'p-lucas', 'p-laura', 'p-helena'};
  const valorAvulso = {
    'p-pedro': 160.0,
    'p-sophia': 180.0,
    'p-davi': 170.0,
    'p-gabriel': 190.0,
  };

  // Histórico: dias úteis do mês anterior até ontem.
  final inicioHistorico = DateTime(hoje.year, hoje.month - 1, 1);
  for (
    var dia = inicioHistorico;
    dia.isBefore(hoje.inicioDoDia);
    dia = DateTime(dia.year, dia.month, dia.day + 1)
  ) {
    if (dia.weekday > DateTime.friday) continue;
    for (final prof in pacientesDe.keys) {
      for (final (h, m) in Salas.grade) {
        if (rnd.nextDouble() < 0.3) continue; // horário vago
        final lista = pacientesDe[prof]!;
        final pac = lista[rnd.nextInt(lista.length)];
        final sorteio = rnd.nextDouble();
        final status = sorteio < 0.03
            ? StatusAgendamento.cancelado
            : sorteio < 0.05
            ? StatusAgendamento.faltou
            : StatusAgendamento.concluido;
        final a = novo(
          pac,
          prof,
          dia.comHora(h, m),
          status: status,
          evolucaoSalva: status == StatusAgendamento.concluido,
        );
        agendamentos.add(a);
        if (status == StatusAgendamento.concluido &&
            valorAvulso.containsKey(pac)) {
          final pagoNoDia = rnd.nextDouble() < 0.85;
          cobrancas.add(
            Cobranca(
              id: 'cb-${a.id}',
              pacienteId: pac,
              pacienteNome: porId[pac]!.nome,
              responsavelNome: porId[pac]!.responsavelNome,
              descricao: pac == 'p-sophia' || pac == 'p-gabriel'
                  ? 'Sessão de Audiologia (45min)'
                  : 'Sessão Avulsa Fonética (45min)',
              valor: valorAvulso[pac]!,
              vencimento: dia,
              pagoEm: pagoNoDia ? dia.comHora(h + 1, 0) : null,
              forma: pagoNoDia
                  ? (rnd.nextDouble() < 0.7
                        ? FormaPagamento.pix
                        : FormaPagamento.cartao)
                  : null,
            ),
          );
        }
      }
    }
  }
  // Sessões do Gabriel/Sophia antigas e não pagas viram "pagas" para não
  // poluir a lista; ficam em aberto só as do cenário abaixo.
  for (var i = 0; i < cobrancas.length; i++) {
    final c = cobrancas[i];
    if (!c.paga) {
      cobrancas[i] = Cobranca(
        id: c.id,
        pacienteId: c.pacienteId,
        pacienteNome: c.pacienteNome,
        responsavelNome: c.responsavelNome,
        descricao: c.descricao,
        valor: c.valor,
        vencimento: c.vencimento,
        pagoEm: c.vencimento.add(const Duration(days: 2, hours: 10)),
        forma: FormaPagamento.convenio,
      );
    }
  }

  // ---- Hoje: o cenário do protótipo.
  final dPedro = novo(
    'p-pedro',
    ContasDemo.ana,
    hoje.comHora(8, 30),
    status: StatusAgendamento.concluido,
    evolucaoSalva: true,
    id: 'ag-hoje-pedro',
  );
  final dLaura = novo(
    'p-laura',
    ContasDemo.ana,
    hoje.comHora(10, 0),
    status: StatusAgendamento.concluido,
    evolucaoSalva: true,
    id: 'ag-hoje-laura',
  );
  final dHelena =
      novo(
        'p-helena',
        ContasDemo.marcos,
        hoje.comHora(10, 0),
        duracao: 50,
        id: 'ag-hoje-helena',
      ).copyWith(
        status: StatusAgendamento.emAtendimento,
        chegadaEm: hoje.comHora(9, 52),
        iniciadoEm: hoje.comHora(10, 4),
        chegadaPor: 'Camila',
      );
  final dLucas =
      novo(
        'p-lucas',
        ContasDemo.ana,
        hoje.comHora(11, 30),
        id: 'ag-hoje-lucas',
      ).copyWith(
        status: StatusAgendamento.naRecepcao,
        chegadaEm: hoje.comHora(11, 24),
        chegadaPor: 'Camila',
      );
  final dMaite = novo(
    'p-maite',
    ContasDemo.ana,
    hoje.comHora(14, 0),
    status: StatusAgendamento.confirmado,
    id: 'ag-hoje-maite',
  );
  final dDavi = novo(
    'p-davi',
    ContasDemo.marcos,
    hoje.comHora(14, 0),
    id: 'ag-hoje-davi',
  );
  final dSophia = novo(
    'p-sophia',
    ContasDemo.beatriz,
    hoje.comHora(15, 30),
    tipo: 'Avaliação Audiológica',
    id: 'ag-hoje-sophia',
  );
  final dGabriel = novo(
    'p-gabriel',
    ContasDemo.beatriz,
    hoje.comHora(10, 0),
    tipo: 'Adaptação de AASI',
    status: StatusAgendamento.concluido,
    evolucaoSalva: true,
    id: 'ag-hoje-gabriel',
  );
  agendamentos.addAll([
    dPedro,
    dLaura,
    dGabriel,
    dHelena,
    dLucas,
    dMaite,
    dDavi,
    Agendamento.fromMap(dSophia.id, {
      ...dSophia.toMap(),
      'whatsappConfirmado': true,
    }),
  ]);

  // ---- Próximos dias úteis: só manhãs (deixa a tarde livre para trocas).
  for (var i = 1; i <= 10; i++) {
    final dia = DateTime(hoje.year, hoje.month, hoje.day + i);
    if (dia.weekday > DateTime.friday) continue;
    for (final prof in pacientesDe.keys) {
      for (final (h, m) in Salas.grade.take(3)) {
        if (rnd.nextDouble() < 0.35) continue;
        final lista = pacientesDe[prof]!;
        agendamentos.add(
          novo(
            lista[rnd.nextInt(lista.length)],
            prof,
            dia.comHora(h, m),
            status: i <= 2
                ? StatusAgendamento.confirmado
                : StatusAgendamento.agendado,
          ),
        );
      }
    }
  }

  for (final a in agendamentos) {
    escritor.set('agendamentos', a.id, a.toMap());
  }

  // ---- Evoluções (SOAP) já assinadas.
  final evolucaoPedro = Evolucao(
    id: dPedro.id,
    pacienteId: 'p-pedro',
    profissionalId: ContasDemo.ana,
    profissionalNome: 'Dra. Ana Costa',
    data: dPedro.inicio,
    subjetivo: 'Mãe relata que Pedro começou a combinar duas palavras em casa ("qué água").',
    objetivo: 'Nomeou 14 de 20 figuras do vocabulário-alvo. Imitação de gestos com apoio mínimo.',
    avaliacao:
        'Ampliação lexical consistente. Melhora da intenção comunicativa.',
    plano: 'Manter estimulação com livros de figuras e rotina de nomeação.',
    acolhimento: 'Chegou sonolento, mas engajou após atividade com blocos.',
    acertos: 14,
    tentativas: 20,
    finalizada: true,
    sessaoNumero: dPedro.sessaoNumero,
  );
  escritor.set('evolucoes', evolucaoPedro.id, evolucaoPedro.toMap());

  final sessoesAnterioresMaite = agendamentos
      .where(
        (a) =>
            a.pacienteId == 'p-maite' &&
            a.status == StatusAgendamento.concluido,
      )
      .toList();
  final textosMaite = [
    (
      'Mãe relata que Maitê está mais confiante para falar com os colegas.',
      'Acerto de 65% no /s/ em sílabas isoladas.',
      'Boa percepção do ponto articulatório com apoio visual do espelho.',
      'Iniciar treino em palavras dissílabas com /s/ inicial.',
      13,
      20,
    ),
    (
      'Família realizou o treino domiciliar 3x na semana.',
      'Acerto de 72% no /s/ em palavras CV.',
      'Transição da sílaba para a palavra em andamento.',
      'Introduzir jogo de caça ao som e reforço lúdico.',
      18,
      25,
    ),
  ];
  for (
    var i = 0;
    i < textosMaite.length && i < sessoesAnterioresMaite.length;
    i++
  ) {
    final a = sessoesAnterioresMaite[sessoesAnterioresMaite.length - 1 - i];
    final t = textosMaite[textosMaite.length - 1 - i];
    final e = Evolucao(
      id: a.id,
      pacienteId: 'p-maite',
      profissionalId: a.profissionalId,
      profissionalNome: a.profissionalNome,
      data: a.inicio,
      subjetivo: t.$1,
      objetivo: t.$2,
      avaliacao: t.$3,
      plano: t.$4,
      acertos: t.$5,
      tentativas: t.$6,
      finalizada: true,
      sessaoNumero: a.sessaoNumero,
    );
    escritor.set('evolucoes', e.id, e.toMap());
  }

  // ---- Solicitação de reagendamento pendente (Maitê: hoje 14h → +2 dias úteis 15h).
  var pretendido = DateTime(hoje.year, hoje.month, hoje.day + 2);
  while (pretendido.weekday > DateTime.friday) {
    pretendido = pretendido.add(const Duration(days: 1));
  }
  escritor.set(
    'solicitacoes',
    'sol-maite',
    SolicitacaoReagendamento(
      id: 'sol-maite',
      agendamentoId: dMaite.id,
      pacienteId: 'p-maite',
      pacienteNome: 'Maitê Silva',
      responsavelNome: 'Juliana Silva',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      sala: dMaite.sala,
      horarioAtual: dMaite.inicio,
      horarioPretendido: pretendido.comHora(15, 0),
      criadoEm: hoje.subtract(const Duration(minutes: 22)),
      motivo:
          'Conflito escolar no horário atual. ${Formatos.diaSemanaCurto(pretendido)} às 15h seria perfeito para a nossa rotina familiar.',
      protocolo: 'RG-8842',
    ).toMap(),
  );
  final reagendadoLucas = hoje.subtract(const Duration(days: 3));
  escritor.set(
    'solicitacoes',
    'sol-lucas',
    SolicitacaoReagendamento(
      id: 'sol-lucas',
      agendamentoId: dLucas.id,
      pacienteId: 'p-lucas',
      pacienteNome: 'Lucas Ferreira',
      responsavelNome: 'Rafael Ferreira',
      profissionalId: ContasDemo.ana,
      profissionalNome: 'Dra. Ana Costa',
      sala: dLucas.sala,
      horarioAtual: reagendadoLucas.comHora(9, 0),
      horarioPretendido: dLucas.inicio,
      criadoEm: reagendadoLucas.comHora(8, 10),
      motivo: 'Consulta médica no horário da manhã.',
      status: StatusSolicitacao.aprovada,
      protocolo: 'RG-8790',
      resolvidoPor: 'Camila Rocha',
      resolvidoEm: reagendadoLucas.comHora(8, 40),
      horarioFinal: dLucas.inicio,
    ).toMap(),
  );

  // ---- Exercícios domiciliares.
  final exercicios = [
    Exercicio(
      id: 'ex-maite-s',
      pacienteId: 'p-maite',
      titulo: 'Palavras com o som /s/',
      categoria: 'Fonema Fricativo Alveolar',
      descricao: 'Repetição guiada em formato de caça ao som',
      instrucao: 'Ajude a Maitê a manter a ponta da língua suave atrás dos dentes sem projetar para fora.',
      orientacaoPais: 'Não corrija imediatamente se a Maitê errar a pronúncia. Apenas repita a palavra corretamente com um sorriso, por exemplo: "Nossa, que lindo esse sapato azul!". O afeto reforça o aprendizado neuromuscular.',
      estimulos: const [
        Estimulo('sapato', '👟'),
        Estimulo('sapo', '🐸'),
        Estimulo('sola', '🦶'),
        Estimulo('sino', '🔔'),
      ],
      frequencia: '1x ao dia',
      duracaoMin: 10,
      fase: 2,
      metaSemanal: 4,
      praticasSemana: 2,
      prescritoPorId: ContasDemo.ana,
      prescritoPorNome: 'Dra. Ana Costa',
      criadoEm: hoje.subtract(const Duration(days: 5)),
      ultimaPratica: hoje.subtract(const Duration(days: 1)).comHora(17, 30),
    ),
    Exercicio(
      id: 'ex-maite-bolhas',
      pacienteId: 'p-maite',
      titulo: 'Respiração diafragmática com bolhas',
      categoria: 'Sopro e Respiração',
      descricao: 'Soprar bolhas de sabão controlando a saída do ar',
      instrucao: 'Peça para a Maitê encher a barriga de ar pelo nariz e soprar devagar pela boca.',
      orientacaoPais: 'Façam juntos: quem consegue a maior bolha?',
      estimulos: const [Estimulo('bolha', '🫧'), Estimulo('sopro', '🌬️')],
      frequencia: '1x ao dia',
      duracaoMin: 3,
      metaSemanal: 7,
      praticasSemana: 5,
      prescritoPorId: ContasDemo.ana,
      prescritoPorNome: 'Dra. Ana Costa',
      criadoEm: hoje.subtract(const Duration(days: 12)),
    ),
    Exercicio(
      id: 'ex-maite-pb',
      pacienteId: 'p-maite',
      titulo: 'Discriminação auditiva P vs B',
      categoria: 'Percepção Auditiva',
      descricao: 'Apontar a figura correta: pato ou bato?',
      instrucao: 'Fale a palavra sem mostrar a boca e peça para ela apontar.',
      estimulos: const [Estimulo('pato', '🦆'), Estimulo('bola', '⚽')],
      metaSemanal: 4,
      praticasSemana: 4,
      status: StatusExercicio.concluido,
      prescritoPorId: ContasDemo.ana,
      prescritoPorNome: 'Dra. Ana Costa',
      criadoEm: hoje.subtract(const Duration(days: 20)),
      ultimaPratica: hoje.subtract(const Duration(days: 8)),
    ),
  ];
  for (final e in exercicios) {
    escritor.set('exercicios', e.id, e.toMap());
  }

  // ---- Mensalidades e cobranças do cenário.
  final mesAnterior = DateTime(hoje.year, hoje.month - 1, 1);
  const mensalidades = {
    'p-maite': ('Plano Mensal Fonoaudiologia • 4 sessões', 480.0),
    'p-lucas': ('Terapia Infantil Mensal • 4 sessões', 480.0),
    'p-laura': ('Terapia Infantil Mensal • 4 sessões', 480.0),
    'p-helena': ('Pacote Voz Adulto • Mensal', 520.0),
  };
  for (final pid in mensalistas) {
    final (desc, valor) = mensalidades[pid]!;
    final p = porId[pid]!;
    // Mês anterior: tudo pago.
    cobrancas.add(
      Cobranca(
        id: 'mens-$pid-ant',
        pacienteId: pid,
        pacienteNome: p.nome,
        responsavelNome: p.responsavelNome,
        descricao: desc,
        valor: valor,
        vencimento: DateTime(mesAnterior.year, mesAnterior.month, 10),
        pagoEm: DateTime(mesAnterior.year, mesAnterior.month, 9, 14),
        forma: pid == 'p-helena' ? FormaPagamento.cartao : FormaPagamento.pix,
      ),
    );
  }
  cobrancas.addAll([
    Cobranca(
      id: 'mens-p-maite',
      pacienteId: 'p-maite',
      pacienteNome: 'Maitê Silva',
      responsavelNome: 'Juliana Silva',
      descricao: mensalidades['p-maite']!.$1,
      valor: 480,
      vencimento: hoje.add(const Duration(days: 3)),
      avisoEnviado: true,
    ),
    Cobranca(
      id: 'mens-p-lucas',
      pacienteId: 'p-lucas',
      pacienteNome: 'Lucas Ferreira',
      responsavelNome: 'Rafael Ferreira',
      descricao: mensalidades['p-lucas']!.$1,
      valor: 480,
      vencimento: hoje.subtract(const Duration(days: 4)),
      pagoEm: hoje.subtract(const Duration(days: 5)),
      forma: FormaPagamento.pix,
    ),
    Cobranca(
      id: 'mens-p-laura',
      pacienteId: 'p-laura',
      pacienteNome: 'Laura Nunes',
      responsavelNome: 'Tiago Nunes',
      descricao: mensalidades['p-laura']!.$1,
      valor: 480,
      vencimento: hoje.subtract(const Duration(days: 2)),
      pagoEm: hoje.subtract(const Duration(days: 2)),
      forma: FormaPagamento.convenio,
    ),
    Cobranca(
      id: 'mens-p-helena',
      pacienteId: 'p-helena',
      pacienteNome: 'Helena Prado',
      descricao: mensalidades['p-helena']!.$1,
      valor: 520,
      vencimento: hoje.subtract(const Duration(days: 2)),
      pagoEm: hoje.subtract(const Duration(days: 2)),
      forma: FormaPagamento.cartao,
    ),
    Cobranca(
      id: 'cb-hoje-pedro',
      pacienteId: 'p-pedro',
      pacienteNome: 'Pedro Alencar',
      responsavelNome: 'Carla Alencar',
      descricao: 'Sessão Avulsa Fonética (45min)',
      valor: 160,
      vencimento: hoje,
      pagoEm: hoje.comHora(9, 20),
      forma: FormaPagamento.pix,
    ),
    Cobranca(
      id: 'cb-sophia-avaliacao',
      pacienteId: 'p-sophia',
      pacienteNome: 'Sophia Mendes',
      responsavelNome: 'Paula Mendes',
      descricao: 'Avaliação Audiológica Completa',
      valor: 350,
      vencimento: hoje.subtract(const Duration(days: 6)),
      avisoEnviado: true,
    ),
  ]);
  if (estresse > 0) {
    _gerarEstresse(escritor, hoje, estresse, nomesProfissionais, salaDe);
  }

  for (final c in cobrancas) {
    escritor.set('cobrancas', c.id, c.toMap());
  }

  await escritor.concluir();
}

/// Massa de dados para o teste de estresse: [n] cobranças no mês atual (elas
/// aparecem na lista do Financeiro) e [n] agendamentos de 2 a 14 meses atrás
/// (o painel precisa percorrê-los, mas não mudam os números exibidos).
void _gerarEstresse(
  _Escritor escritor,
  DateTime hoje,
  int n,
  Map<String, String> nomesProfissionais,
  Map<String, String> salaDe,
) {
  const nomes = [
    'Ana',
    'Bruno',
    'Carla',
    'Diego',
    'Elisa',
    'Fábio',
    'Gabriela',
    'Heitor',
    'Isabela',
    'João',
    'Kauã',
    'Larissa',
    'Miguel',
    'Natália',
    'Otávio',
    'Paula',
    'Rafael',
    'Sara',
    'Tiago',
    'Valentina',
  ];
  const sobrenomes = [
    'Almeida',
    'Barbosa',
    'Cardoso',
    'Dias',
    'Esteves',
    'Freitas',
    'Gomes',
    'Lopes',
    'Moreira',
    'Nogueira',
    'Oliveira',
    'Pereira',
    'Ribeiro',
    'Santos',
  ];
  final rnd = Random(42);
  final ultimoDia = DateTime(hoje.year, hoje.month + 1, 0).day;
  final profissionais = nomesProfissionais.keys.toList();

  for (var i = 0; i < n; i++) {
    final k = i % 300;
    final pid = 'p-estresse-$k';
    final nome =
        '${nomes[k % nomes.length]} ${sobrenomes[(k ~/ nomes.length) % sobrenomes.length]}';
    final responsavel =
        '${nomes[(k + 7) % nomes.length]} ${nome.split(' ').last}';

    final venc = DateTime(hoje.year, hoje.month, 1 + rnd.nextInt(ultimoDia));
    final paga = rnd.nextDouble() < 0.55 && !venc.isAfter(hoje);
    final c = Cobranca(
      id: 'cb-estresse-$i',
      pacienteId: pid,
      pacienteNome: nome,
      responsavelNome: responsavel,
      descricao: rnd.nextBool()
          ? 'Sessão Avulsa Fonética (45min)'
          : 'Terapia Infantil Mensal • 4 sessões',
      valor: 150.0 + rnd.nextInt(8) * 10,
      vencimento: venc,
      pagoEm: paga ? venc.comHora(9 + rnd.nextInt(8), 0) : null,
      forma: paga
          ? FormaPagamento.values[rnd.nextInt(FormaPagamento.values.length)]
          : null,
    );
    escritor.set('cobrancas', c.id, c.toMap());

    final prof = profissionais[i % profissionais.length];
    final (h, m) = Salas.grade[rnd.nextInt(Salas.grade.length)];
    final dia = DateTime(
      hoje.year,
      hoje.month - 2 - rnd.nextInt(12),
      1 + rnd.nextInt(28),
    );
    final inicio = dia.comHora(h, m);
    final sorteio = rnd.nextDouble();
    final a = Agendamento(
      id: 'ag-estresse-$i',
      pacienteId: pid,
      pacienteNome: nome,
      pacienteNascimento: DateTime(hoje.year - 4 - k % 30, 1 + k % 12, 10),
      profissionalId: prof,
      profissionalNome: nomesProfissionais[prof]!,
      sala: salaDe[prof]!,
      inicio: inicio,
      fim: inicio.add(const Duration(minutes: Salas.duracaoPadraoMin)),
      tipo: 'Terapia',
      status: sorteio < 0.04
          ? StatusAgendamento.cancelado
          : sorteio < 0.07
          ? StatusAgendamento.faltou
          : StatusAgendamento.concluido,
      sessaoNumero: 1 + i ~/ 300,
      evolucaoSalva: true,
    );
    escritor.set('agendamentos', a.id, a.toMap());
  }
}

/// Junta todas as gravações e envia num lote só.
class _Escritor {
  _Escritor(this.banco);
  final BancoDados banco;
  final _operacoes = <Operacao>[];

  void set(String colecao, String id, Map<String, dynamic> dados) =>
      _operacoes.add(Gravar(colecao, id, dados));

  Future<void> concluir() => banco.lote(_operacoes);
}
