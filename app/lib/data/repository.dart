import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'engine.dart';
import 'keep_alive.dart';
import 'model.dart';
import 'sources/source.dart';

/// Punto único de datos para la interfaz.
///
/// - [load]: lee la última cartelera guardada en el móvil (instantáneo).
/// - [refresh]: vuelve a leer todas las webs de los cines desde el propio móvil,
///   notifica el progreso en [progress] y guarda el resultado.
/// - [snapshot] es null solo antes de la primera lectura.
class CarteleraRepository extends ChangeNotifier {
  Snapshot? snapshot;
  RefreshProgress? progress; // != null mientras se actualiza
  String? lastError;

  bool get refreshing => progress != null;

  /// Hora a partir de la cual la cartelera se considera vieja y se actualiza sola al abrir.
  static const staleAfter = Duration(hours: 6);
  bool get isStale =>
      snapshot == null || _fromSample || DateTime.now().difference(snapshot!.generatedAt) > staleAfter;

  /// true mientras se enseñan los datos de ejemplo del paquete (nunca se ha actualizado).
  bool _fromSample = false;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/cartelera.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        snapshot = Snapshot.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      } else {
        // Primera vez: datos de ejemplo del paquete hasta la primera actualización.
        final raw = await rootBundle.loadString('assets/sample_snapshot.json');
        snapshot = Snapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _fromSample = true;
      }
    } catch (e) {
      lastError = 'No se pudo leer la cartelera guardada: $e';
    }
    notifyListeners();
  }

  Future<void> save(Snapshot s) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(s.toJson()));
  }

  /// Vuelve a leer las webs desde el móvil.
  ///
  /// - [sources]: las fuentes que se leen (por defecto, todas). Lo que no se lee no se
  ///   conserva: así una fuente desactivada desaparece de la cartelera guardada.
  /// - [partial]: solo se leen [sources] y se mezclan con lo que ya había (al activar una
  ///   fuente, sin volver a leer todas).
  ///
  /// Mientras dura, [RefreshKeepAlive] impide que Android congele la app si se sale de ella.
  Future<void> refresh({List<Source>? sources, bool partial = false}) async {
    if (refreshing) return;
    progress = RefreshProgress(total: 1, done: 0, running: const [], finished: const []);
    notifyListeners();
    await RefreshKeepAlive.start();
    try {
      final prev = snapshot;
      var s = await runRefresh(previous: prev, sources: sources, onProgress: (p) {
        progress = p;
        RefreshKeepAlive.progress(p.done, p.total);
        notifyListeners();
      });
      if (partial && prev != null && !_fromSample) s = _merge(prev, s);
      snapshot = s;
      _fromSample = false;
      lastError = null;
      await save(s);
    } catch (e) {
      lastError = 'Error al actualizar: $e';
    } finally {
      progress = null;
      await RefreshKeepAlive.stop();
      notifyListeners();
    }
  }

  /// Lectura parcial sobre la cartelera anterior: lo de las fuentes recién leídas sustituye
  /// a lo suyo de antes; el resto se queda como estaba.
  static Snapshot _merge(Snapshot prev, Snapshot fresh) {
    final ids = {for (final f in fresh.sources) f.id};
    final sessions = [
      for (final s in prev.sessions)
        if (!ids.contains(s.source)) s,
      ...fresh.sessions,
    ]..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : a.cinema.compareTo(b.cinema);
      });
    final order = {for (var i = 0; i < allSources.length; i++) allSources[i].id: i};
    final statuses = [
      for (final s in prev.sources)
        if (!ids.contains(s.id)) s,
      ...fresh.sources,
    ]..sort((a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99));
    return Snapshot(generatedAt: prev.generatedAt, sources: statuses, sessions: sessions);
  }

  /// Quita de la cartelera guardada lo de las fuentes indicadas (al desactivarlas).
  Future<void> dropSources(Set<String> ids) async {
    final s = snapshot;
    if (s == null || ids.isEmpty || refreshing) return;
    if (!s.sources.any((f) => ids.contains(f.id)) && !s.sessions.any((x) => ids.contains(x.source))) return;
    snapshot = Snapshot(
      generatedAt: s.generatedAt,
      sources: [for (final f in s.sources) if (!ids.contains(f.id)) f],
      sessions: [for (final x in s.sessions) if (!ids.contains(x.source)) x],
    );
    notifyListeners();
    if (!_fromSample) await save(snapshot!);
  }
}

typedef ProgressCallback = void Function(RefreshProgress p);

/// Motor real: lee todas las webs desde el móvil (lib/data/engine.dart).
Future<Snapshot> runRefresh({Snapshot? previous, List<Source>? sources, required ProgressCallback onProgress}) =>
    refreshAll(previous: previous, sources: sources, onProgress: onProgress);
