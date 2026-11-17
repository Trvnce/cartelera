import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Cineteca Madrid: /programacion para saber qué títulos hay (ciclo y sección) y la ficha
/// de cada uno para sala, horas y enlace de compra. En su formulario «to» es el inicio
/// y «since» el fin (nombres cruzados en la web).
const _base = 'https://www.cinetecamadrid.com';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final cineteca = Source(
  id: 'cineteca',
  name: 'Cineteca Madrid',
  url: '$_base/programacion',
  fetch: (Net net) async {
    final t = today();
    final end = t.add(const Duration(days: 7));
    final films = <String, Map<String, Object?>>{};
    for (var page = 0; page < 8; page++) {
      final doc = parseHtml(await net.getText('$_base/programacion?to=${_ymd(t)}&since=${_ymd(end)}&page=$page'));
      final items = doc.querySelectorAll('.content-wrap .field-name-node-title a');
      if (items.isEmpty) break;
      var added = 0;
      for (final a in items) {
        var wrap = a.parent;
        while (wrap != null && !wrap.classes.contains('content-wrap')) {
          wrap = wrap.parent;
        }
        final href = absUrl(_base, a.attributes['href'])!;
        if (films.containsKey(href) || wrap == null) continue;
        added++;
        final prog = txt(wrap.querySelector('.field-name-field-program a'));
        final sec = txt(wrap.querySelector('.field-name-field-parent-section a'));
        films[href] = {
          'title': txt(a),
          'cycle': prog.isEmpty ? null : tidyTitle(prog),
          'section': sec.isEmpty ? null : tidyTitle(sec),
          'duration': firstInt(txt(wrap.querySelector('.field-name-field-duration'))),
        };
      }
      if (added == 0) break;
    }

    final out = <Session>[];
    for (final e in films.entries) {
      final doc = parseHtml(await net.getText(e.key));
      final box = doc.querySelector('.sb-sessions__items');
      if (box == null) continue;
      final buy = doc.querySelector('.field--name-field-ticketing-links a');
      final poster = doc.querySelector('.field-name-field-poster a');
      String? director;
      int? year;
      final pt = poster?.attributes['title'];
      if (pt != null) {
        final pm = RegExp(r'\(([^()]*)\)\s*$').firstMatch(pt);
        if (pm != null) {
          final parts = pm.group(1)!.split(',').map(clean).toList();
          if (parts.isNotEmpty && RegExp(r'^\d{4}$').hasMatch(parts.last)) year = int.parse(parts.last);
          if (parts.length >= 3) director = parts.first;
        }
      }
      int? month;
      int? day;
      for (final el in box.querySelectorAll('h2, h4, ul')) {
        final s = txt(el);
        if (el.localName == 'h2') {
          month = monthOf(s);
        } else if (el.localName == 'h4') {
          day = firstInt(s);
        } else if (el.localName == 'ul' && month != null && day != null) {
          final hours = el.querySelectorAll('.sb-sessions__date-hours-hour');
          final rooms = el.querySelectorAll('.sb-sessions__date-hours-space');
          for (var i = 0; i < hours.length; i++) {
            final d = DateTime(inferYear(month, day), month, day);
            if (d.isBefore(t)) continue;
            out.add(Session(
              source: 'cineteca',
              cinema: 'Cineteca Madrid',
              title: e.value['title'] as String,
              start: at(d, txt(hours[i])),
              room: i < rooms.length ? txt(rooms[i]) : null,
              year: year,
              director: director,
              durationMin: e.value['duration'] as int?,
              cycle: e.value['cycle'] as String?,
              section: e.value['section'] as String?,
              ticketUrl: buy?.attributes['href'],
              infoUrl: e.key,
              poster: absUrl(_base, poster?.attributes['href']),
            ));
          }
        }
      }
    }
    return out;
  },
);
