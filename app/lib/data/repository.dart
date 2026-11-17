import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'engine.dart';
import 'model.dart';

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

  /// La implementación real vive en `refresh_engine.dart` (lectores portados a Dart).
  Future<void> refresh() async {
    if (refreshing) return;
    progress = RefreshProgress(total: 1, done: 0, running: const [], finished: const []);
    notifyListeners();
    try {
      final s = await runRefresh(previous: snapshot, onProgress: (p) {
        progress = p;
        notifyListeners();
      });
      snapshot = s;
      _fromSample = false;
      lastError = null;
      await save(s);
    } catch (e) {
      lastError = 'Error al actualizar: $e';
    } finally {
      progress = null;
      notifyListeners();
    }
  }
}

typedef ProgressCallback = void Function(RefreshProgress p);

/// Motor real: lee todas las webs desde el móvil (lib/data/engine.dart).
Future<Snapshot> runRefresh({Snapshot? previous, required ProgressCallback onProgress}) =>
    refreshAll(previous: previous, onProgress: onProgress);
