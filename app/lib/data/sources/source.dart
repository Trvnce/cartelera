import 'package:html/dom.dart';
import 'package:html/parser.dart' as hp;

import '../model.dart';
import '../net.dart';

/// Un lector: lee la web de un cine (o varios) y devuelve sus pases.
class Source {
  const Source({required this.id, required this.name, required this.url, required this.fetch, this.emptyIsOk = false});
  final String id;
  final String name; // nombre visible en la pantalla de fuentes
  final String url; // web del cine
  final Future<List<Session>> Function(Net net) fetch;

  /// Que no salga ningún pase es normal (no un fallo de lectura): p. ej., eCartelera solo
  /// publica las sesiones de hoy que aún no han empezado, y de noche no queda ninguna. El
  /// propio lector lanza un error si la página no tiene la forma esperada.
  final bool emptyIsOk;
}

Document parseHtml(String s) => hp.parse(s);

String txt(Element? e) => (e?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

Element? q(Element e, String sel) => e.querySelector(sel);
List<Element> qa(Element e, String sel) => e.querySelectorAll(sel);
