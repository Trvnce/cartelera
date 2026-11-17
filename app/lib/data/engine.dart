import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'classify.dart';
import 'model.dart';
import 'net.dart';
import 'posters.dart';
import 'sources/academia.dart';
import 'sources/berlanga.dart';
import 'sources/casamerica.dart';
import 'sources/cba.dart';
import 'sources/cineteca.dart';
import 'sources/ecartelera.dart';
import 'sources/embajadores.dart';
import 'sources/equis.dart';
import 'sources/filmoteca.dart';
import 'sources/golem.dart';
import 'sources/renoir.dart';
import 'sources/source.dart';
import 'sources/verdi.dart';

/// Todas las fuentes, en el orden en que se enseñan.
final allSources = <Source>[
  filmoteca, cineteca, renoir, golem, embajadores, verdi, cba, academia,
  berlanga, equis, casamerica, ecartelera,
];

/// Lee todas las fuentes desde el móvil. Cada fuente va por su lado (en paralelo) y
/// [Net] espacia las peticiones a una misma web. Una fuente rota no tumba a las demás:
/// de ella se conserva lo último bueno de [previous], marcado como `stale`.
Future<Snapshot> refreshAll({
  Snapshot? previous,
  required void Function(RefreshProgress p) onProgress,
  List<Source>? sources,
}) async {
  final list = sources ?? allSources;
  final net = await Net.create();
  final now = DateTime.now();
  final running = <String>{for (final s in list) s.name};
  final finished = <SourceStatus>[];
  final sessions = <Session>[];

  void report() => onProgress(RefreshProgress(
        total: list.length + 1, // +1: pósters
        done: finished.length,
        running: running.toList(),
        finished: List.of(finished),
      ));
  report();

  try {
    await Future.wait(list.map((src) async {
      String? error;
      var got = <Session>[];
      try {
        got = (await src.fetch(net).timeout(const Duration(minutes: 3))).map(classify).toList();
        if (got.isEmpty) error = 'La web respondió pero no se leyó ningún pase (¿ha cambiado?)';
      } catch (e) {
        error = _short(e);
      }
      sessions.addAll(got);
      running.remove(src.name);
      finished.add(SourceStatus(id: src.id, name: src.name, url: src.url, ok: error == null, count: got.length, error: error, at: now));
      report();
    }));

    running.add('Pósters');
    report();
    final dir = await getApplicationSupportDirectory();
    try {
      await fillPosters(sessions, net, File('${dir.path}/posters.json')).timeout(const Duration(minutes: 2));
    } catch (_) {}
    running.remove('Pósters');
  } finally {
    net.close();
  }

  // De las fuentes que fallaron hoy, lo último que se supo (solo pases futuros).
  final failed = {for (final f in finished) if (!f.ok) f.id};
  if (previous != null && failed.isNotEmpty) {
    for (final s in previous.sessions) {
      if (failed.contains(s.source) && s.start.isAfter(now)) {
        s.stale = true;
        sessions.add(s);
      }
    }
  }

  sessions.sort((a, b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : a.cinema.compareTo(b.cinema);
  });
  final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
  finished.sort((a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99));
  return Snapshot(generatedAt: now, sources: finished, sessions: sessions);
}

String _short(Object e) {
  final s = e.toString().replaceFirst(RegExp(r'^(Exception|HttpException|SocketException|HandshakeException|ClientException):\s*'), '');
  if (e is HandshakeException || s.contains('CERTIFICATE_VERIFY_FAILED')) return 'Certificado de la web no válido para el móvil';
  if (e is SocketException || s.contains('Failed host lookup')) return 'Sin conexión con la web';
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}
