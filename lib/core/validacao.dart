/// Validadores de formulário (retornam a mensagem de erro ou null).
abstract final class Validacao {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? obrigatorio(String? v, [String campo = 'Campo']) =>
      (v == null || v.trim().isEmpty) ? '$campo é obrigatório' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    if (!_email.hasMatch(v.trim())) return 'E-mail inválido';
    return null;
  }

  static String? senha(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 6) return 'Mínimo de 6 caracteres';
    return null;
  }

  static String? nomeCompleto(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o nome';
    if (v.trim().split(RegExp(r'\s+')).length < 2) {
      return 'Informe nome e sobrenome';
    }
    return null;
  }

  /// Registro do Conselho de Fonoaudiologia, ex.: "CRFa 2-19402".
  static String? crfa(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o CRFa';
    if (!RegExp(
      r'^(CRFa\s*)?\d{1,2}-\d{3,6}$',
      caseSensitive: false,
    ).hasMatch(v.trim())) {
      return 'Formato esperado: CRFa 2-12345';
    }
    return null;
  }
}
