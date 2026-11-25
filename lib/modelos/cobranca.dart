import 'conversao.dart';

enum FormaPagamento {
  pix('PIX'),
  cartao('Cartão'),
  convenio('Convênio');

  const FormaPagamento(this.rotulo);
  final String rotulo;
}

enum SituacaoCobranca { paga, pendente, atrasada }

class Cobranca {
  const Cobranca({
    required this.id,
    required this.pacienteId,
    required this.pacienteNome,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    this.responsavelNome = '',
    this.pagoEm,
    this.forma,
    this.avisoEnviado = false,
  });

  final String id;
  final String pacienteId;
  final String pacienteNome;
  final String responsavelNome;
  final String descricao;
  final double valor;
  final DateTime vencimento;
  final DateTime? pagoEm;
  final FormaPagamento? forma;
  final bool avisoEnviado;

  bool get paga => pagoEm != null;

  // depende de hoje, não vai pro banco
  SituacaoCobranca situacao(DateTime hoje) {
    if (paga) return SituacaoCobranca.paga;
    return _chaveDia(vencimento) < _chaveDia(hoje)
        ? SituacaoCobranca.atrasada
        : SituacaoCobranca.pendente;
  }

  // 2026-11-24 -> 20261124. Criar DateTime local consulta o fuso do SO e
  // isso roda milhares de vezes no sort, então compara como int.
  static int _chaveDia(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  int diasDeAtraso(DateTime hoje) {
    final venc = DateTime(vencimento.year, vencimento.month, vencimento.day);
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    return dia.difference(venc).inDays;
  }

  Map<String, dynamic> toMap() => {
    'pacienteId': pacienteId,
    'pacienteNome': pacienteNome,
    'responsavelNome': responsavelNome,
    'descricao': descricao,
    'valor': valor,
    'vencimento': gravarData(vencimento),
    'pagoEm': gravarDataOpcional(pagoEm),
    'forma': forma?.name,
    'avisoEnviado': avisoEnviado,
  };

  factory Cobranca.fromMap(String id, Map<String, dynamic> m) => Cobranca(
    id: id,
    pacienteId: m['pacienteId'] as String? ?? '',
    pacienteNome: m['pacienteNome'] as String? ?? '',
    responsavelNome: m['responsavelNome'] as String? ?? '',
    descricao: m['descricao'] as String? ?? '',
    valor: (m['valor'] as num?)?.toDouble() ?? 0,
    vencimento: lerData(m['vencimento']),
    pagoEm: lerDataOpcional(m['pagoEm']),
    forma: m['forma'] == null
        ? null
        : lerEnum(FormaPagamento.values, m['forma'], FormaPagamento.pix),
    avisoEnviado: m['avisoEnviado'] as bool? ?? false,
  );
}
