import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Um documento lido do banco: id + campos.
typedef Documento = ({String id, Map<String, dynamic> dados});

/// Valor especial para somar a um campo numérico (como FieldValue.increment).
class Incremento {
  const Incremento(this.valor);
  final num valor;
}

/// Operações que podem ir num lote atômico.
sealed class Operacao {
  const Operacao(this.colecao, this.id);
  final String colecao;
  final String id;
}

class Gravar extends Operacao {
  const Gravar(super.colecao, super.id, this.dados);
  final Map<String, dynamic> dados;
}

class Atualizar extends Operacao {
  const Atualizar(super.colecao, super.id, this.dados);
  final Map<String, dynamic> dados;
}

class Apagar extends Operacao {
  const Apagar(super.colecao, super.id);
}

/// Contrato mínimo de banco de documentos usado pelo app.
///
/// Existem duas implementações:
/// - [FirestoreBanco]: Cloud Firestore de verdade (dados na nuvem);
/// - [MemoriaBanco]: tudo em memória, para a demonstração e os testes.
abstract class BancoDados {
  /// Observa uma coleção inteira, ou só os documentos com `campo == igualA`.
  Stream<List<Documento>> colecao(String nome, {String? campo, Object? igualA});

  /// Observa só os documentos com `de <= campo < ate` (campo de data).
  ///
  /// Consulta de intervalo num único campo: o Firestore usa o índice
  /// automático e baixa só o pedaço pedido, em vez da coleção inteira.
  Stream<List<Documento>> colecaoEntre(
    String nome, {
    required String campo,
    required DateTime de,
    required DateTime ate,
  });

  /// Observa um documento (null se não existir).
  Stream<Documento?> documento(String colecao, String id);

  /// Leitura única de uma consulta.
  Future<List<Documento>> buscar(
    String colecao, {
    String? campo,
    Object? igualA,
  });

  /// Gera um id novo para a coleção.
  String novoId(String colecao);

  /// Aplica as operações de forma atômica.
  Future<void> lote(List<Operacao> operacoes);

  Future<void> gravar(String colecao, String id, Map<String, dynamic> dados) =>
      lote([Gravar(colecao, id, dados)]);

  Future<void> atualizar(
    String colecao,
    String id,
    Map<String, dynamic> dados,
  ) => lote([Atualizar(colecao, id, dados)]);

  Future<void> apagar(String colecao, String id) => lote([Apagar(colecao, id)]);
}

// --------------------------------------------------------------- Firestore

/// Adaptador para o Cloud Firestore.
class FirestoreBanco extends BancoDados {
  FirestoreBanco(this.db);
  final FirebaseFirestore db;

  Query<Map<String, dynamic>> _consulta(
    String nome,
    String? campo,
    Object? igualA,
  ) {
    final c = db.collection(nome);
    return campo == null ? c : c.where(campo, isEqualTo: igualA);
  }

  static List<Documento> _docs(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) (id: d.id, dados: d.data()),
  ];

  @override
  Stream<List<Documento>> colecao(
    String nome, {
    String? campo,
    Object? igualA,
  }) => _consulta(nome, campo, igualA).snapshots().map(_docs);

  @override
  Stream<List<Documento>> colecaoEntre(
    String nome, {
    required String campo,
    required DateTime de,
    required DateTime ate,
  }) => db
      .collection(nome)
      .where(
        campo,
        isGreaterThanOrEqualTo: Timestamp.fromDate(de),
        isLessThan: Timestamp.fromDate(ate),
      )
      .snapshots()
      .map(_docs);

  @override
  Stream<Documento?> documento(String colecao, String id) => db
      .collection(colecao)
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? (id: s.id, dados: s.data()!) : null);

  @override
  Future<List<Documento>> buscar(
    String colecao, {
    String? campo,
    Object? igualA,
  }) async => _docs(await _consulta(colecao, campo, igualA).get());

  @override
  String novoId(String colecao) => db.collection(colecao).doc().id;

  static Map<String, dynamic> _converter(Map<String, dynamic> dados) => {
    for (final e in dados.entries)
      e.key: e.value is Incremento
          ? FieldValue.increment((e.value as Incremento).valor)
          : e.value,
  };

  @override
  Future<void> lote(List<Operacao> operacoes) async {
    // O Firestore aceita até 500 operações por batch.
    for (var i = 0; i < operacoes.length; i += 400) {
      final batch = db.batch();
      for (final op in operacoes.skip(i).take(400)) {
        final ref = db.collection(op.colecao).doc(op.id);
        switch (op) {
          case Gravar(:final dados):
            batch.set(ref, _converter(dados));
          case Atualizar(:final dados):
            batch.update(ref, _converter(dados));
          case Apagar():
            batch.delete(ref);
        }
      }
      await batch.commit();
    }
  }
}

// ----------------------------------------------------------------- Memória

/// Banco em memória com atualização em tempo real (streams), usado na
/// demonstração e nos testes. Os dados somem ao recarregar a página.
class MemoriaBanco extends BancoDados {
  final _colecoes = <String, Map<String, Map<String, dynamic>>>{};
  final _mudancas = StreamController<String>.broadcast(sync: true);
  int _contador = 0;

  Map<String, Map<String, dynamic>> _col(String nome) =>
      _colecoes.putIfAbsent(nome, () => {});

  List<Documento> _ler(String nome, String? campo, Object? igualA) => [
    for (final e in _col(nome).entries)
      if (campo == null || e.value[campo] == igualA)
        (id: e.key, dados: Map.of(e.value)),
  ];

  /// Emite o estado atual e depois a cada mudança na coleção.
  Stream<T> _observar<T>(String nome, T Function() ler) {
    late StreamController<T> c;
    StreamSubscription<String>? sub;
    c = StreamController<T>(
      onListen: () {
        c.add(ler());
        sub = _mudancas.stream
            .where((n) => n == nome)
            .listen((_) => c.add(ler()));
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<Documento>> colecao(
    String nome, {
    String? campo,
    Object? igualA,
  }) => _observar(nome, () => _ler(nome, campo, igualA));

  @override
  Stream<List<Documento>> colecaoEntre(
    String nome, {
    required String campo,
    required DateTime de,
    required DateTime ate,
  }) => _observar(
    nome,
    () => [
      for (final e in _col(nome).entries)
        if (_entre(e.value[campo], de, ate))
          (id: e.key, dados: Map.of(e.value)),
    ],
  );

  static bool _entre(Object? valor, DateTime de, DateTime ate) {
    final d = switch (valor) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };
    return d != null && !d.isBefore(de) && d.isBefore(ate);
  }

  @override
  Stream<Documento?> documento(String colecao, String id) =>
      _observar(colecao, () {
        final d = _col(colecao)[id];
        return d == null ? null : (id: id, dados: Map.of(d));
      });

  @override
  Future<List<Documento>> buscar(
    String colecao, {
    String? campo,
    Object? igualA,
  }) async => _ler(colecao, campo, igualA);

  @override
  String novoId(String colecao) =>
      '$colecao-${DateTime.now().microsecondsSinceEpoch}-${_contador++}';

  @override
  Future<void> lote(List<Operacao> operacoes) async {
    // Valida antes de aplicar, para o lote ser "tudo ou nada".
    for (final op in operacoes) {
      if (op is Atualizar && !_col(op.colecao).containsKey(op.id)) {
        throw StateError('Documento ${op.colecao}/${op.id} não existe.');
      }
    }
    final alteradas = <String>{};
    for (final op in operacoes) {
      final col = _col(op.colecao);
      switch (op) {
        case Gravar(:final dados):
          col[op.id] = _semIncrementos(dados, const {});
        case Atualizar(:final dados):
          col[op.id] = {...col[op.id]!, ..._semIncrementos(dados, col[op.id]!)};
        case Apagar():
          col.remove(op.id);
      }
      alteradas.add(op.colecao);
    }
    // Avisa os ouvintes de forma assíncrona, como o Firestore.
    await Future<void>.delayed(Duration.zero);
    alteradas.forEach(_mudancas.add);
  }

  static Map<String, dynamic> _semIncrementos(
    Map<String, dynamic> novos,
    Map<String, dynamic> atuais,
  ) => {
    for (final e in novos.entries)
      e.key: e.value is Incremento
          ? ((atuais[e.key] as num?) ?? 0) + (e.value as Incremento).valor
          : e.value,
  };
}
