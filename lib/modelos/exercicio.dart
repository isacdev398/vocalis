import 'conversao.dart';

enum StatusExercicio { ativo, concluido }

/// Palavra-estímulo exibida na prática (com um emoji lúdico).
class Estimulo {
  const Estimulo(this.palavra, [this.emoji = '🗣️']);
  final String palavra;
  final String emoji;

  /// Separação silábica simples, usada como "transcrição" de apoio.
  String get silabas => _silabas(palavra);

  Map<String, dynamic> toMap() => {'palavra': palavra, 'emoji': emoji};
  factory Estimulo.fromMap(Map<String, dynamic> m) =>
      Estimulo(m['palavra'] as String? ?? '', m['emoji'] as String? ?? '🗣️');

  static String _silabas(String p) {
    const vogais = 'aeiouáéíóúâêôãõà';
    final r = StringBuffer();
    for (var i = 0; i < p.length; i++) {
      r.write(p[i]);
      final ehVogal = vogais.contains(p[i].toLowerCase());
      final temProxima = i + 2 < p.length;
      if (ehVogal &&
          temProxima &&
          !vogais.contains(p[i + 1].toLowerCase()) &&
          vogais.contains(p[i + 2].toLowerCase())) {
        r.write('-');
      }
    }
    return r.toString();
  }
}

/// Exercício domiciliar prescrito pela fono (`exercicios/{id}`).
class Exercicio {
  const Exercicio({
    required this.id,
    required this.pacienteId,
    required this.titulo,
    required this.criadoEm,
    this.objetivo = 'Fonologia e Articulação',
    this.categoria = '',
    this.descricao = '',
    this.instrucao = '',
    this.orientacaoPais = '',
    this.estimulos = const [],
    this.frequencia = '1x ao dia',
    this.duracaoMin = 10,
    this.fase = 1,
    this.totalFases = 4,
    this.metaSemanal = 4,
    this.praticasSemana = 0,
    this.status = StatusExercicio.ativo,
    this.prescritoPorId = '',
    this.prescritoPorNome = '',
    this.ultimaPratica,
  });

  final String id;
  final String pacienteId;
  final String titulo;
  final DateTime criadoEm;
  final String objetivo;

  /// Ex.: "Fonema Fricativo Alveolar"
  final String categoria;
  final String descricao;
  final String instrucao;
  final String orientacaoPais;
  final List<Estimulo> estimulos;
  final String frequencia;
  final int duracaoMin;
  final int fase;
  final int totalFases;
  final int metaSemanal;
  final int praticasSemana;
  final StatusExercicio status;
  final String prescritoPorId;
  final String prescritoPorNome;
  final DateTime? ultimaPratica;

  bool get concluido => status == StatusExercicio.concluido;
  double get progressoSemanal =>
      metaSemanal == 0 ? 0 : (praticasSemana / metaSemanal).clamp(0, 1);

  Map<String, dynamic> toMap() => {
    'pacienteId': pacienteId,
    'titulo': titulo,
    'criadoEm': gravarData(criadoEm),
    'objetivo': objetivo,
    'categoria': categoria,
    'descricao': descricao,
    'instrucao': instrucao,
    'orientacaoPais': orientacaoPais,
    'estimulos': estimulos.map((e) => e.toMap()).toList(),
    'frequencia': frequencia,
    'duracaoMin': duracaoMin,
    'fase': fase,
    'totalFases': totalFases,
    'metaSemanal': metaSemanal,
    'praticasSemana': praticasSemana,
    'status': status.name,
    'prescritoPorId': prescritoPorId,
    'prescritoPorNome': prescritoPorNome,
    'ultimaPratica': gravarDataOpcional(ultimaPratica),
  };

  factory Exercicio.fromMap(String id, Map<String, dynamic> m) => Exercicio(
    id: id,
    pacienteId: m['pacienteId'] as String? ?? '',
    titulo: m['titulo'] as String? ?? '',
    criadoEm: lerData(m['criadoEm']),
    objetivo: m['objetivo'] as String? ?? '',
    categoria: m['categoria'] as String? ?? '',
    descricao: m['descricao'] as String? ?? '',
    instrucao: m['instrucao'] as String? ?? '',
    orientacaoPais: m['orientacaoPais'] as String? ?? '',
    estimulos: ((m['estimulos'] as List?) ?? [])
        .map((e) => Estimulo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(),
    frequencia: m['frequencia'] as String? ?? '1x ao dia',
    duracaoMin: (m['duracaoMin'] as num?)?.toInt() ?? 10,
    fase: (m['fase'] as num?)?.toInt() ?? 1,
    totalFases: (m['totalFases'] as num?)?.toInt() ?? 4,
    metaSemanal: (m['metaSemanal'] as num?)?.toInt() ?? 4,
    praticasSemana: (m['praticasSemana'] as num?)?.toInt() ?? 0,
    status: lerEnum(StatusExercicio.values, m['status'], StatusExercicio.ativo),
    prescritoPorId: m['prescritoPorId'] as String? ?? '',
    prescritoPorNome: m['prescritoPorNome'] as String? ?? '',
    ultimaPratica: lerDataOpcional(m['ultimaPratica']),
  );
}
