import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Verdi Madrid: el JSON que usa su web (/api/get-events), con precio de cada pase,
/// versión, proyección e id de IMDb. No publica sala.
const _base = 'https://madrid.cines-verdi.com';

final verdi = Source(
  id: 'verdi',
  name: 'Verdi Madrid',
  url: '$_base/',
  fetch: (Net net) async {
    final data = await net.getJson('$_base/api/get-events') as Map<String, dynamic>;
    final now = DateTime.now();
    final out = <Session>[];
    for (final e in (data['result'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final raw = clean((e['locale_title'] ?? e['title_name'])?.toString());
      final directors = ((e['directors'] as List?) ?? const [])
          .whereType<List>()
          .where((d) => d.length > 1)
          .map((d) => d[1].toString())
          .join(', ');
      final year = int.tryParse('${e['year'] ?? ''}');
      final projection = clean(e['projection']?.toString());
      final keywords = clean(e['keywords']?.toString());
      final slug = e['title_slug']?.toString();
      for (final p in ((e['performances'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
        final ts = p['time'].toString();
        final start = DateTime(int.parse(ts.substring(0, 4)), int.parse(ts.substring(4, 6)), int.parse(ts.substring(6, 8)),
            int.parse(ts.substring(8, 10)), int.parse(ts.substring(10, 12)));
        if (start.isBefore(now)) continue;
        final prices = ((((p['data'] as Map?)?['tickets'] as Map?)?['prices'] as List?) ?? const [])
            .map((x) => int.tryParse('$x'))
            .whereType<int>()
            .map((c) => c / 100)
            .toList();
        double? max, min;
        if (prices.isNotEmpty) {
          max = prices.reduce((a, b) => a > b ? a : b);
          min = prices.reduce((a, b) => a < b ? a : b);
        }
        out.add(Session(
          source: 'verdi',
          cinema: 'Verdi Madrid',
          title: stripVersion(raw),
          rawTitle: raw,
          start: start,
          version: detectVersion([e['version']?.toString(), raw]),
          director: directors.isEmpty ? null : directors,
          year: year,
          durationMin: int.tryParse('${e['runtime'] ?? ''}'),
          cycle: keywords.isEmpty ? null : keywords,
          tags: projection.isNotEmpty && !const ['digital 2d', 'digital'].contains(projection.toLowerCase()) ? [projection] : [],
          note: clean(e['notice']?.toString()).isEmpty ? null : clean(e['notice']?.toString()),
          priceEur: max,
          priceNote: max == null
              ? null
              : 'Precio del pase${min != null && min != max ? ' · reducida desde ${min.toStringAsFixed(2).replaceAll('.', ',')} €' : ''}',
          ticketUrl: slug != null ? '$_base/$slug' : _base,
          infoUrl: slug != null ? '$_base/$slug' : null,
          imdbId: e['imdbid']?.toString(),
        ));
      }
    }
    return out;
  },
);
