import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Mantiene viva la app mientras se actualiza, aunque el usuario salga de ella.
///
/// En Android arranca un servicio en primer plano (RefreshService.kt) con una notificación
/// de progreso; sin él, el sistema congela la app en segundo plano y las lecturas fallan
/// al volver. En el resto de plataformas no hace nada: allí cubre el reintento del motor.
class RefreshKeepAlive {
  static const _ch = MethodChannel('cartelera/refresh_service');
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static int _lastDone = -1;

  static Future<void> start() async {
    if (!_supported) return;
    _lastDone = -1;
    try {
      await _ch.invokeMethod<bool>('start');
    } catch (_) {/* sin servicio: la lectura sigue igual */}
  }

  static void progress(int done, int total) {
    if (!_supported || done == _lastDone) return;
    _lastDone = done;
    _ch.invokeMethod<void>('progress', {'done': done, 'total': total}).catchError((_) {});
  }

  static Future<void> stop() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
