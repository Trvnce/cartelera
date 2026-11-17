import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Sala Equis: la taquilla rellena las horas por JavaScript, pero cada mes publica un PDF
/// con un calendario de 8 columnas. Se reparte cada carácter en su columna por posición y
/// se lee día a día. Carteles y enlace de compra salen de /taquilla/.
const _home = 'https://salaequis.es/';
const _taquilla = 'https://salaequis.es/taquilla/';
const _cols = 8;
final _dayRe = RegExp(r'^(\d{1,2})\s+(LUNES|MARTES|MI[EÉ]RCOLES|JUEVES|VIERNES|S[AÁ]BADO|DOMINGO)\b');
final _timeRe = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*h:\s*(.*)');
final _creditsRe = RegExp(r'(.*?),?\s*(\d{4})\s*-+\s*(VOSE|VO/VOSE|VO|VE|V\.O\.S\.E\.)\s*-+\s*(\d+)?');
final _prefixRe = RegExp(r'^F*FESTIVAL [A-ZÁÉÍÓÚÑ]+$|^CINE POR MUJERES$|^AETERNA$|^PASE ESPECIAL$|^EQUIS [A-Z]+$');
final _cycleRe = RegExp(r'^(FESTIVAL [^-:]+|CINE POR MUJERES|AETERNA|PASE ESPECIAL|EQUIS [A-Z]+|FESTIVAL ANFIBIA)\s*[-:]\s*(.+)$');

/// Texto de la página 1 repartido en 8 columnas, con saltos de línea.
Future<List<String>> _columns(List<int> bytes) async {
  await pdfrxFlutterInitialize();
  final doc = await PdfDocument.openData(Uint8List.fromList(bytes));
  try {
    final page = doc.pages.first;
    final text = await page.loadStructuredText();
    final w = page.width;
    final buf = List.generate(_cols, (_) => StringBuffer());
    final lastTop = List<double?>.filled(_cols, null);
    for (var i = 0; i < text.fullText.length && i < text.charRects.length; i++) {
      final ch = text.fullText[i];
      if (ch == '\n' || ch == '\r') continue;
      final r = text.charRects[i];
      final c = (r.left / (w / _cols)).floor().clamp(0, _cols - 1);
      final prev = lastTop[c];
      if (prev != null && (prev - r.top).abs() > 3) buf[c].write('\n');
      lastTop[c] = r.top;
      buf[c].write(ch);
    }
    return buf.map((b) => b.toString()).toList();
  } finally {
    await doc.dispose();
  }
}

List<Map<String, dynamic>> _parseColumns(List<String> cols) {
  final items = <Map<String, dynamic>>[];
  for (final col in cols) {
    int? day;
    Map<String, dynamic>? cur;
    void flush() {
      final c = cur;
      if (c != null && (c['title'] as String).isNotEmpty) items.add(c);
    }

    for (final line in col.split('\n').map(clean).where((x) => x.isNotEmpty)) {
      final dm = _dayRe.firstMatch(line);
      if (dm != null) {
        flush();
        cur = null;
        day = int.parse(dm.group(1)!);
        continue;
      }
      if (day == null) continue;
      final tm = _timeRe.firstMatch(line);
      if (tm != null) {
        flush();
        cur = {'day': day, 'time': '${tm.group(1)}:${tm.group(2) ?? '00'}', 'title': tm.group(3)!, 'credits': '', 'note': null, 'done': false};
        continue;
      }
      final c = cur;
      if (c == null || line.contains('NO HAY SESIONES')) continue;
      if (line.startsWith('*')) {
        c['note'] = line.replaceFirst(RegExp(r'^\*+'), '').trim();
        c['done'] = true;
      } else if (_creditsRe.hasMatch(line) || RegExp(r'^(Director:|\d{4}\s*-)').hasMatch(line) || RegExp(r',\s*\d{4}\s*-*\s*$').hasMatch(line)) {
        c['credits'] = '${c['credits']} $line';
        c['done'] = true;
      } else if (RegExp(r"^\d+\s*[’'´]?$").hasMatch(line)) {
        c['credits'] = '${c['credits']} $line';
      } else if (c['done'] != true) {
        var t = c['title'] as String;
        var sep = ' ';
        if (t.endsWith('-') && !_prefixRe.hasMatch(t.substring(0, t.length - 1).trim())) {
          t = t.substring(0, t.length - 1); // «SIEMPREVI-» + «VAS»
          sep = '';
        } else if (t.endsWith('-')) {
          sep = '';
        }
        c['title'] = (t + sep + line).trim();
      } else {
        c['credits'] = '${c['credits']} $line';
      }
    }
    flush();
  }
  return items;
}

final equis = Source(
  id: 'equis',
  name: 'Sala Equis (PDF del mes)',
  url: _home,
  fetch: (Net net) async {
    final t = today();
    final home = await net.getText(_home);
    final pm = RegExp(r'href="([^"]+\.pdf)"').firstMatch(home);
    if (pm == null) throw Exception('No se encuentra el PDF del mes en la portada');
    final pdfUrl = Uri.parse(pm.group(1)!).toString(); // codifica la tilde combinada
    final cols = await _columns(await net.getBytes(pdfUrl));
    final mm = RegExp(r'\b(\d{2})/(20\d{2})\b').firstMatch(cols.join(' '));
    final month = mm != null ? int.parse(mm.group(1)!) : t.month;
    final year = mm != null ? int.parse(mm.group(2)!) : t.year;

    // Carteles y fichas de la taquilla.
    final taq = <String, (String?, String)>{};
    final tdoc = parseHtml(await net.getText(_taquilla));
    for (final row in tdoc.querySelectorAll('div.row')) {
      final a = row.querySelector('.title a');
      if (a == null) continue;
      final img = row.querySelector('img[data-src]');
      var src = img?.attributes['data-src'];
      if (src != null) src = src.replaceAllMapped(RegExp(r'-\d+x\d+(\.\w+)$'), (m) => m.group(1)!);
      taq[normTitle(txt(a))] = (src, a.attributes['href'] ?? _taquilla);
    }

    final out = <Session>[];
    for (final it in _parseColumns(cols)) {
      final d = DateTime(year, month, it['day'] as int);
      if (d.isBefore(t)) continue;
      var title = (it['title'] as String).replaceFirst(RegExp(r'^F+ESTIVAL'), 'FESTIVAL').replaceAll(RegExp(r'-$'), '');
      String? cycle;
      final m = _cycleRe.firstMatch(title);
      if (m != null) {
        cycle = m.group(1);
        title = m.group(2)!;
      } else {
        final (t2, c2) = splitCycle(title);
        title = t2;
        cycle = c2;
      }
      final cm = _creditsRe.firstMatch(it['credits'] as String);
      final director = cm == null ? null : clean(cm.group(1)).replaceFirst(RegExp(r'^Director:\s*'), '').replaceAll(RegExp(r'[\s,-]+$'), '');
      final (poster, info) = taq[normTitle(title)] ?? (null, null);
      out.add(Session(
        source: 'equis',
        cinema: 'Sala Equis',
        title: tidyTitle(title),
        rawTitle: it['title'] as String,
        start: at(d, it['time'] as String),
        room: 'Sala única',
        version: cm != null ? detectVersion([cm.group(3)]) : null,
        director: (director ?? '').isEmpty ? null : director,
        year: cm != null ? int.parse(cm.group(2)!) : null,
        durationMin: cm?.group(4) != null ? int.parse(cm!.group(4)!) : null,
        cycle: cycle != null ? capWords(cycle) : null,
        note: it['note'] as String?,
        ticketUrl: info ?? _taquilla,
        infoUrl: info,
        poster: poster,
      ));
    }
    return out;
  },
);
