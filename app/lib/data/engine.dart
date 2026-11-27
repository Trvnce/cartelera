import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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
  berlanga, equis, casamerica, ...ecarteleraSources,
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

  // Una lectura de una fuente. `transient`: el fallo es de red o de tiempo (no de la web),
  // y merece un segundo intento.
  Future<({List<Session> got, String? error, bool transient})> read(Source src) async {
    try {
      final got = (await src.fetch(net).timeout(const Duration(minutes: 3))).map(classify).toList();
      return (got: got, error: got.isEmpty && !src.emptyIsOk ? 'La web respondió pero no se leyó ningún pase (¿ha cambiado?)' : null, transient: false);
    } catch (e) {
      return (got: <Session>[], error: _short(e), transient: _isTransient(e));
    }
  }

  void finish(Source src, ({List<Session> got, String? error, bool transient}) r) {
    sessions.addAll(r.got);
    running.remove(src.name);
    finished.removeWhere((f) => f.id == src.id);
    finished.add(SourceStatus(id: src.id, name: src.name, url: src.url, ok: r.error == null, count: r.got.length, error: r.error, at: now));
    report();
  }

  try {
    final retry = <Source>[];
    await Future.wait(list.map((src) async {
      final r = await read(src);
      if (r.transient) retry.add(src);
      finish(src, r);
    }));

    // Segundo intento para lo que falló por la red o por tiempo: pasa, sobre todo, si el
    // sistema ha dormido la app a mitad de lectura y, al despertar, todas las esperas
    // han vencido de golpe.
    if (retry.isNotEmpty) {
      await Future<void>.delayed(const Duration(seconds: 2));
      running.addAll(retry.map((s) => s.name));
      report();
      await Future.wait(retry.map((src) async => finish(src, await read(src))));
    }

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

bool _isTransient(Object e) {
  if (e is TimeoutException || e is SocketException || e is http.ClientException) return true;
  if (e is HttpException) {
    final code = int.tryParse(RegExp(r'^HTTP (\d{3})').firstMatch(e.message)?.group(1) ?? '');
    return code == null || code >= 500 || code == 429;
  }
  return false;
}

String _short(Object e) {
  final s = e.toString().replaceFirst(RegExp(r'^(Exception|HttpException|SocketException|HandshakeException|ClientException):\s*'), '');
  if (e is HandshakeException || s.contains('CERTIFICATE_VERIFY_FAILED')) return 'Certificado de la web no válido para el móvil';
  if (e is SocketException || s.contains('Failed host lookup')) return 'Sin conexión con la web';
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}
