// Leitura em voz alta das palavras-estímulo.
// Na web usa a síntese de voz do navegador; nas outras plataformas não faz nada.
export 'fala_stub.dart' if (dart.library.js_interop) 'fala_web.dart';
