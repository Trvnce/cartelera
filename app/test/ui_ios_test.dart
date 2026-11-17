// Recorrido en modo iPhone: comprueba que se usan los componentes de iOS y que
// todo se puede usar sin desbordes ni excepciones.

import 'dart:convert';
import 'dart:io';

import 'package:cartelera/data/model.dart';
import 'package:cartelera/data/repository.dart';
import 'package:cartelera/ui/app_model.dart';
import 'package:cartelera/ui/screens/home_screen.dart';
import 'package:cartelera/ui/theme.dart';
import 'package:cartelera/ui/widgets/film_card.dart';
import 'package:cartelera/ui/widgets/session_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo extends CarteleraRepository {
  @override
  bool get isStale => false;

  @override
  Future<void> load() async {
    final base = Snapshot.fromJson(jsonDecode(File('assets/sample_snapshot.json').readAsStringSync()) as Map<String, dynamic>);
    final shift = DateTime.now().difference(DateTime(2026, 11, 17)).inDays;
    snapshot = Snapshot(
      generatedAt: DateTime.now(),
      sources: base.sources,
      sessions: [
        for (final s in base.sessions)
          Session.fromJson({
            ...s.toJson(),
            'start': DateTime(s.start.year, s.start.month, s.start.day + shift, s.start.hour, s.start.minute).toIso8601String(),
            'poster': null,
          }),
      ],
    );
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('recorrido en iPhone con componentes de iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(390, 844); // iPhone 13/14/15
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final model = AppModel(_FakeRepo());
    await tester.runAsync(model.init);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: HomeScreen(model: model)));
    await tester.pumpAndSettle();

    // Barra de pestañas y barra superior de iOS (no las de Material).
    expect(find.byType(CupertinoTabBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    expect(find.byType(FilmCard), findsWidgets);

    // Ordenar: hoja de acción nativa.
    await tester.tap(find.byIcon(CupertinoIcons.arrow_up_arrow_down));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Búsqueda con el campo de iOS.
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSearchTextField), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Agenda → ficha → favorita → volver con la flecha de iOS.
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SessionTile).at(1));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoNavigationBarBackButton), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.heart));
    await tester.pumpAndSettle();
    expect(model.favorites, hasLength(1));
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();

    // Favoritas.
    await tester.tap(find.text('Favoritas'));
    await tester.pumpAndSettle();
    expect(find.byType(FilmCard), findsOneWidget);

    // Filtros con interruptores de iOS y «Cerrar».
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Solo pases especiales'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    // Switch.adaptive pinta el interruptor de iOS desde el propio Switch (no crea CupertinoSwitch).
    expect(find.byType(SwitchListTile), findsWidgets);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    // Fuentes, desde el botón de la izquierda.
    await tester.tap(find.byIcon(CupertinoIcons.antenna_radiowaves_left_right));
    await tester.pumpAndSettle();
    expect(find.text('Fuentes'), findsWidgets);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    model.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
