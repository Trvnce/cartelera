import 'package:cartelera/data/alerts.dart';
import 'package:cartelera/data/model.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 27, 12);

Session _s(String title, {String source = 'renoir', String cinema = 'Renoir Princesa', int day = 28, int hour = 20, List<String>? tags, bool stale = false}) =>
    Session(source: source, cinema: cinema, title: title, start: DateTime(2026, 11, day, hour), tags: tags, stale: stale);

SourceStatus _st(String id, {bool ok = true}) =>
    SourceStatus(id: id, name: id, url: 'https://$id', ok: ok, count: 1, at: _now);

Snapshot _snap(List<Session> sessions, {List<SourceStatus>? sources}) =>
    Snapshot(generatedAt: _now, sources: sources ?? [_st('renoir'), _st('academia')], sessions: sessions);

void main() {
  final watchFilm = AlertPrefs(films: {normTitle('Perfect Days'): 'Perfect Days'});

  test('avisa de un pase nuevo de una película vigilada', () {
    final prev = _snap([_s('Perfect Days', hour: 18)]);
    final fresh = _snap([_s('Perfect Days', hour: 18), _s('Perfect Days', hour: 22), _s('Otra', hour: 22)]);
    final found = newAlertMatches(prev, fresh, watchFilm, now: _now);
    expect(found.map((s) => s.start.hour), [22]);
    expect(found.single.title, 'Perfect Days');
  });

  test('avisa de cualquier pase nuevo en un cine vigilado', () {
    final prefs = AlertPrefs(sources: {'academia'});
    final prev = _snap([]);
    final fresh = _snap([
      _s('Coloquio', source: 'academia', cinema: 'Academia de Cine'),
      _s('Solo socios', source: 'academia', cinema: 'Academia de Cine', tags: ['solo académicos']),
      _s('En otro cine'),
    ]);
    expect(newAlertMatches(prev, fresh, prefs, now: _now).map((s) => s.title), ['Coloquio']);
  });

  test('sin lectura anterior, o si la fuente falló la vez anterior, no hay nada nuevo', () {
    final fresh = _snap([_s('Perfect Days')]);
    expect(newAlertMatches(null, fresh, watchFilm, now: _now), isEmpty);
    final failed = _snap([], sources: [_st('renoir', ok: false)]);
    expect(newAlertMatches(failed, fresh, watchFilm, now: _now), isEmpty);
    // Fuente recién activada: no estaba en la lectura anterior.
    final without = _snap([], sources: [_st('academia')]);
    expect(newAlertMatches(without, fresh, watchFilm, now: _now), isEmpty);
  });

  test('ignora pases ya empezados y los heredados de una lectura vieja', () {
    final prev = _snap([]);
    final fresh = _snap([_s('Perfect Days', day: 27, hour: 10), _s('Perfect Days', stale: true)]);
    expect(newAlertMatches(prev, fresh, watchFilm, now: _now), isEmpty);
  });

  test('qué fuentes se leen en segundo plano', () {
    final onlyCinema = AlertPrefs(sources: {'academia', 'golem'});
    expect(onlyCinema.sourcesToRead({'golem'}).map((s) => s.id), ['academia']);
    final ids = watchFilm.sourcesToRead({}).map((s) => s.id).toList();
    expect(ids, containsAll(['academia', 'renoir', 'filmoteca']));
  });

  test('la mezcla parcial sustituye solo lo de las fuentes leídas', () {
    final prev = _snap([_s('Vieja Renoir'), _s('Academia', source: 'academia', cinema: 'Academia de Cine')]);
    final fresh = Snapshot(generatedAt: _now.add(const Duration(hours: 1)), sources: [_st('renoir')], sessions: [_s('Nueva Renoir')]);
    final m = mergePartialSnapshot(prev, fresh);
    expect(m.sessions.map((s) => s.title), unorderedEquals(['Nueva Renoir', 'Academia']));
    expect(m.generatedAt, prev.generatedAt); // no se leyó todo
    final all = Snapshot(generatedAt: fresh.generatedAt, sources: [_st('renoir'), _st('academia')], sessions: const []);
    expect(mergePartialSnapshot(prev, all).generatedAt, fresh.generatedAt);
  });

  test('las preferencias se guardan y se leen igual', () async {
    final a = AlertPrefs(films: {'x': 'X'}, sources: {'golem'}, interval: const Duration(minutes: 30));
    expect(a.isEmpty, isFalse);
    expect(a.copyWith(films: {}, sources: {}).isEmpty, isTrue);
  });
}
