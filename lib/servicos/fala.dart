// Só a web tem síntese de voz por enquanto.
export 'fala_stub.dart' if (dart.library.js_interop) 'fala_web.dart';
