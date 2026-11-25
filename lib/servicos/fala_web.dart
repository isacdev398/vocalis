import 'package:web/web.dart' as web;

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
