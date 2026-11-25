/// Versão para plataformas sem síntese de voz configurada.
/// Retorna false para a tela saber que deve só simular o áudio.
Future<bool> falar(String texto) async => false;
