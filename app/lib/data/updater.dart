import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Actualizaciones de la app desde GitHub Releases (solo Android).
///
/// - Las versiones se publican con una etiqueta `vX.Y.Z` y un `.apk` adjunto
///   (.github/workflows/android.yml). Las Releases `ios-N` del .ipa se ignoran.
/// - Al abrir la app se mira como mucho cada [checkEvery]; si hay una versión más nueva
///   que la instalada se ofrece descargarla, y Android pide confirmar la instalación.
/// - El APK nuevo tiene que estar firmado con la misma clave que el instalado.
abstract final class Updater {
  static const repo = 'Trvnce/cartelera';
  static const checkEvery = Duration(hours: 6);
  static const _kLastCheck = 'update.lastCheck.v1';
  static const _ch = MethodChannel('cartelera/updater');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static final _status = StreamController<({bool ok, String? message})>.broadcast();

  /// Resultado de la instalación que informa Android (si falla, o en raros casos el éxito
  /// antes de cerrar la app).
  static Stream<({bool ok, String? message})> get installStatus {
    _listen();
    return _status.stream;
  }

  static bool _listening = false;
  static void _listen() {
    if (_listening || !supported) return;
    _listening = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'installStatus') {
        final a = Map<String, dynamic>.from(call.arguments as Map);
        _status.add((ok: a['ok'] == true, message: a['message'] as String?));
      }
    });
  }

  /// Versión instalada («1.2.0»).
  static Future<String> installedVersion() async {
    final info = await _ch.invokeMapMethod<String, dynamic>('info');
    return (info?['versionName'] as String?) ?? '0';
  }

  /// Busca una versión más nueva. Sin [force], no pregunta a GitHub si ya lo hizo hace
  /// menos de [checkEvery]. null = no hay nada nuevo (o no se ha podido mirar).
  static Future<AppUpdate?> check({bool force = false, http.Client? client}) async {
    if (!supported) return null;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_kLastCheck) ?? '');
    if (!force && last != null && DateTime.now().difference(last) < checkEvery) return null;
    final current = await installedVersion();
    final c = client ?? http.Client();
    try {
      final r = await c.get(
        Uri.parse('https://api.github.com/repos/$repo/releases?per_page=20'),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'Cartelera-app'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw HttpException('GitHub respondió ${r.statusCode}');
      await prefs.setString(_kLastCheck, DateTime.now().toIso8601String());
      final latest = latestRelease(jsonDecode(r.body) as List<dynamic>);
      if (latest == null || compareVersions(latest.version, current) <= 0) return null;
      return latest;
    } finally {
      if (client == null) c.close();
    }
  }

  /// La versión publicada más nueva con APK, de la lista de Releases de la API de GitHub.
  @visibleForTesting
  static AppUpdate? latestRelease(List<dynamic> releases) {
    AppUpdate? best;
    for (final raw in releases) {
      final r = raw as Map<String, dynamic>;
      if (r['draft'] == true || r['prerelease'] == true) continue;
      final m = RegExp(r'^v(\d+(?:\.\d+)*)$').firstMatch((r['tag_name'] as String?) ?? '');
      if (m == null) continue;
      final assets = (r['assets'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
      final apk = assets.where((a) => ((a['name'] as String?) ?? '').toLowerCase().endsWith('.apk')).firstOrNull;
      if (apk == null) continue;
      final u = AppUpdate(
        version: m.group(1)!,
        notes: ((r['body'] as String?) ?? '').trim(),
        apkUrl: apk['browser_download_url'] as String,
        size: (apk['size'] as num?)?.toInt() ?? 0,
        pageUrl: (r['html_url'] as String?) ?? 'https://github.com/$repo/releases',
      );
      if (best == null || compareVersions(u.version, best.version) > 0) best = u;
    }
    return best;
  }

  /// Compara «1.10.0» con «1.9.2» número a número.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < x.length || i < y.length; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d.sign;
    }
    return 0;
  }

  /// Descarga el APK a la caché de la app, informando del progreso (0–1, o null si no se
  /// sabe el tamaño).
  static Future<File> download(AppUpdate u, {void Function(double? progress)? onProgress}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cartelera-${u.version}.apk');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(u.apkUrl))..headers['User-Agent'] = 'Cartelera-app');
      if (res.statusCode != 200) throw HttpException('La descarga respondió ${res.statusCode}');
      final total = res.contentLength ?? (u.size > 0 ? u.size : null);
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        got += chunk.length;
        onProgress?.call(total == null ? null : got / total);
      }
      await sink.close();
      if (u.size > 0 && got != u.size) throw const HttpException('La descarga se ha cortado');
      return file;
    } finally {
      client.close();
    }
  }

  static Future<bool> canInstall() async => await _ch.invokeMethod<bool>('canInstall') ?? false;
  static Future<void> openInstallSettings() => _ch.invokeMethod<void>('openInstallSettings');

  /// Pasa el APK al instalador de Android (que pide confirmación).
  static Future<void> install(File apk) {
    _listen();
    return _ch.invokeMethod<void>('install', {'path': apk.path});
  }
}

@immutable
class AppUpdate {
  const AppUpdate({required this.version, required this.notes, required this.apkUrl, required this.size, required this.pageUrl});
  final String version;
  final String notes;
  final String apkUrl;
  final int size;
  final String pageUrl;
}
