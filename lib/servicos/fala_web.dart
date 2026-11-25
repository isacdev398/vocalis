import 'package:web/web.dart' as web;

/// Fala o texto em português usando a Web Speech API do navegador.
Future<bool> falar(String texto) async {
  try {
    final sintese = web.window.speechSynthesis;
    sintese.cancel();
    final fala = web.SpeechSynthesisUtterance(texto)
      ..lang = 'pt-BR'
      ..rate = 0.75;
    sintese.speak(fala);
    return true;
  } catch (_) {
    return false;
  }
}
