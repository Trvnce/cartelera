import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'alerts.dart';
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

  /// Qué se vigila para avisar de pases nuevos (lo fija [AppModel]).
  AlertPrefs alerts = AlertPrefs();

  /// Fecha de modificación del fichero cuando se leyó o escribió por última vez: si cambia,
  /// lo ha reescrito la comprobación de avisos en segundo plano.
  DateTime? _fileStamp;

  Future<File> _file() => snapshotFile();

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        snapshot = Snapshot.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        _fileStamp = await f.lastModified();
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
    _fileStamp = await f.lastModified();
  }

  /// Vuelve a leer la cartelera guardada si otro proceso (los avisos en segundo plano) la
  /// ha reescrito desde la última vez. Para llamarlo al volver a la app.
  Future<void> reloadIfChanged() async {
    if (refreshing || _fromSample) return;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final m = await f.lastModified();
      if (_fileStamp != null && !m.isAfter(_fileStamp!)) return;
      snapshot = Snapshot.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
      _fileStamp = m;
      notifyListeners();
    } catch (_) {}
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
      if (partial && prev != null && !_fromSample) s = mergePartialSnapshot(prev, s);
      // Avisos: lo mismo que la comprobación en segundo plano, ahora que ya se ha leído.
      if (!_fromSample) unawaited(AlertNotifier.notify(newAlertMatches(prev, s, alerts)));
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
