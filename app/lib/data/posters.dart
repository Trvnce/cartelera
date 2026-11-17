import 'dart:convert';
import 'dart:io';

import 'model.dart';
import 'net.dart';
import 'sources/source.dart';

/// Completa el póster de los pases que no lo traen:
/// 1. el de otro cine con el mismo título (verticales primero);
/// 2. si no, la og:image de la ficha, leída una vez y guardada en [cacheFile].
const _vertical = {'embajadores': 0, 'golem': 1, 'renoir': 2, 'ecartelera': 3, 'cineteca': 4, 'filmoteca': 5, 'equis': 6};
const _maxFetch = 80;

Future<void> fillPosters(List<Session> sessions, Net net, File cacheFile) async {
  Map<String, String?> cache = {};
  try {
    if (await cacheFile.exists()) {
      cache = (jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>).cast<String, String?>();
    }
  } catch (_) {}

  final byTitle = <String, (int, String)>{};
  for (final s in sessions) {
    if (s.poster == null) continue;
    final rank = _vertical[s.source] ?? 9;
    final cur = byTitle[s.filmKey];
    if (cur == null || rank < cur.$1) byTitle[s.filmKey] = (rank, s.poster!);
  }

  // Fichas que hay que mirar (una por URL), en paralelo; Net ya espacia por web.
  final toFetch = <String>{};
  for (final s in sessions) {
    if (s.poster == null && !byTitle.containsKey(s.filmKey) && s.infoUrl != null && !cache.containsKey(s.infoUrl)) {
      toFetch.add(s.infoUrl!);
    }
  }
  await Future.wait(toFetch.take(_maxFetch).map((url) async {
    try {
      final doc = parseHtml(await net.getText(url));
      final og = doc.querySelector('meta[property="og:image"]')?.attributes['content'] ??
          doc.querySelector('meta[name="twitter:image"]')?.attributes['content'];
      cache[url] = og == null ? null : Uri.parse(url).resolve(og).toString();
    } catch (_) {
      cache[url] = null;
    }
  }));

  for (final s in sessions) {
    if (s.poster != null) continue;
    final t = byTitle[s.filmKey];
    if (t != null) {
      s.poster = t.$2;
      continue;
    }
    final img = s.infoUrl == null ? null : cache[s.infoUrl];
    if (img != null && !RegExp(r'logo|\.svg($|\?)', caseSensitive: false).hasMatch(img)) {
      s.poster = img;
      byTitle[s.filmKey] = (9, img);
    }
  }
  try {
    await cacheFile.writeAsString(jsonEncode(cache));
  } catch (_) {}
}
