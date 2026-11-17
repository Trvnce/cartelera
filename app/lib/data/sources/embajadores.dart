import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Cines Embajadores (Glorieta) y Embajadores Río: cinesembajadores.es/madrid/, cada pase
/// en atributos data-* (día, hora, sala, recinto). Venta en reservaentradas.com.
const _url = 'https://cinesembajadores.es/madrid/';

String? _room(String? raw) {
  final m = RegExp(r'(\d+)').firstMatch(raw ?? '');
  return m != null ? 'Sala ${m.group(1)}' : (clean(raw).isEmpty ? null : clean(raw));
}

final embajadores = Source(
  id: 'embajadores',
  name: 'Embajadores (Glorieta y Río)',
  url: _url,
  fetch: (Net net) async {
    final doc = parseHtml(await net.getText(_url));
    final t = today();
    final out = <Session>[];
    final seen = <String>{};
    for (final movie in doc.querySelectorAll('li.movie')) {
      final a = movie.querySelector('.info h2 a');
      if (a == null) continue;
      final raw = txt(a);
      final (title, cycle) = splitCycle(stripVersion(raw));
      final version = detectVersion([raw, txt(movie.querySelector('li.doblaje'))]);
      String? director;
      for (final h5 in movie.querySelectorAll('.more h5')) {
        final s = txt(h5);
        if (s.toLowerCase().startsWith('direcci')) director = clean(s.split(':').skip(1).join(':'));
      }
      final poster = movie.querySelector('.poster img')?.attributes['src'];
      final dur = firstInt(txt(movie.querySelector('li.minutos')));
      for (final p in movie.querySelectorAll('p[data-dia]')) {
        final dm = (p.attributes['data-dia'] ?? '').split('/');
        final hora = p.attributes['data-hora'];
        if (dm.length != 2 || hora == null) continue;
        final dd = int.parse(dm[0]), mm = int.parse(dm[1]);
        final d = DateTime(inferYear(mm, dd), mm, dd);
        if (d.isBefore(t)) continue;
        final recinto = clean(p.attributes['data-recinto']);
        final s = Session(
          source: 'embajadores',
          cinema: normTitle(recinto).split(' ').contains('rio') ? 'Embajadores Río' : 'Cines Embajadores',
          title: title,
          rawTitle: raw,
          cycle: cycle,
          start: at(d, hora),
          room: _room(p.attributes['data-sala']),
          version: version,
          director: director,
          durationMin: dur,
          ticketUrl: p.querySelector('a')?.attributes['href'],
          infoUrl: a.attributes['href'],
          poster: poster,
        );
        if (seen.add(s.key)) out.add(s); // la cartelera repite películas en varias secciones
      }
    }
    return out;
  },
);
