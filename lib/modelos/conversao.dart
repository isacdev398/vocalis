import 'package:cloud_firestore/cloud_firestore.dart';

/// Converte valores lidos do Firestore para DateTime.
DateTime lerData(Object? valor, [DateTime? padrao]) {
  if (valor is Timestamp) return valor.toDate();
  if (valor is DateTime) return valor;
  if (valor is String) {
    return DateTime.tryParse(valor) ?? padrao ?? DateTime(2000);
  }
  return padrao ?? DateTime(2000);
}

DateTime? lerDataOpcional(Object? valor) =>
    valor == null ? null : lerData(valor);

Timestamp gravarData(DateTime d) => Timestamp.fromDate(d);

Timestamp? gravarDataOpcional(DateTime? d) =>
    d == null ? null : Timestamp.fromDate(d);

T lerEnum<T extends Enum>(List<T> valores, Object? nome, T padrao) =>
    valores.firstWhere((v) => v.name == nome, orElse: () => padrao);
