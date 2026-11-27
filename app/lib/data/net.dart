import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Descargas educadas desde el móvil: navegador «normal», una petición cada
/// [perHostGap] por web y caché en memoria durante una actualización.
class Net {
  Net._(this._client);

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Mobile Safari/537.36 CarteleraPersonal/1.0';
  static const perHostGap = Duration(milliseconds: 900);
  static const timeout = Duration(seconds: 30);

  final http.Client _client;
  final Map<String, Future<Uint8List>> _cache = {};
  final Map<String, Future<void>> _hostQueue = {};

  /// Algunas webs (Embajadores) no envían su certificado intermedio y Android no lo
  /// descarga solo: se añade a la confianza del cliente desde los assets.
  static Future<Net> create() async {
    final ctx = SecurityContext(withTrustedRoots: true);
    for (final a in const ['assets/certs/intermediates.pem']) {
      try {
        final pem = await rootBundle.load(a);
        ctx.setTrustedCertificatesBytes(pem.buffer.asUint8List());
      } catch (_) {/* sin intermedios extra */}
    }
    final io = HttpClient(context: ctx)
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = userAgent;
    return Net._(IOClient(io));
  }

  void close() => _client.close();

  /// Una petición fallida no se queda en la caché: si no, reintentarla dentro de la
  /// misma actualización devolvería el mismo error sin volver a preguntar a la web.
  Future<Uint8List> getBytes(String url) {
    return _cache.putIfAbsent(url, () => _fetch(url).catchError((Object e, StackTrace st) {
          _cache.remove(url);
          return Future<Uint8List>.error(e, st);
        }));
  }

  Future<String> getText(String url) async => decode(await getBytes(url));

  Future<dynamic> getJson(String url) async => jsonDecode(await getText(url));

  Future<Uint8List> _fetch(String url) async {
    final host = Uri.parse(url).host;
    // Encola por web: la siguiente petición al mismo host espera a la anterior + hueco.
    final prev = _hostQueue[host] ?? Future<void>.value();
    final done = Completer<void>();
    _hostQueue[host] = done.future;
    await prev;
    try {
      final resp = await _client.get(Uri.parse(url), headers: {
        'Accept-Language': 'es-ES,es;q=0.9',
        'Accept': 'text/html,application/json,application/pdf,*/*',
      }).timeout(timeout);
      if (resp.statusCode >= 400) {
        throw HttpException('HTTP ${resp.statusCode}', uri: Uri.parse(url));
      }
      return resp.bodyBytes;
    } finally {
      Future<void>.delayed(perHostGap, done.complete);
    }
  }

  /// UTF-8 y, si no cuadra, Windows-1252 (algunas webs mezclan).
  static String decode(Uint8List b) {
    try {
      return utf8.decode(b);
    } on FormatException {
      return latin1.decode(b, allowInvalid: true);
    }
  }
}
