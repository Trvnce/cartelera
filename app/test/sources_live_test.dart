// Prueba EN VIVO de los lectores contra las webs reales (no forma parte de la batería
// normal). Ejecutar a mano:  flutter test test/sources_live_test.dart --tags live
@Tags(['live'])
library;

import 'package:cartelera/data/classify.dart';
import 'package:cartelera/data/engine.dart';
import 'package:cartelera/data/net.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final src in allSources.where((s) => s.id != 'equis')) {
    test('lector ${src.id}', () async {
      final net = await Net.create();
      try {
        final got = (await src.fetch(net)).map(classify).toList();
        final cines = got.map((s) => s.cinema).toSet();
        // ignore: avoid_print
        print('${src.id}: ${got.length} pases · ${cines.length} cines · '
            'con sala ${got.where((s) => s.room != null).length} · con precio ${got.where((s) => s.priceEur != null).length} · '
            'especiales ${got.where((s) => s.isSpecial).length}');
        for (final s in got.take(2)) {
          // ignore: avoid_print
          print('   ${s.start} | ${s.cinema} | ${s.room} | ${s.title} (${s.year}, ${s.director}) | ${s.version} | ${s.cycle} | ${s.tags} | ${s.priceEur}');
        }
        expect(got, isNotEmpty);
      } finally {
        net.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
