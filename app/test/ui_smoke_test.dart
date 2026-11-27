// Recorre las pantallas con los datos reales de ejemplo para cazar
// desbordamientos y excepciones de maquetación.

import 'dart:convert';
import 'dart:io';

import 'package:cartelera/data/model.dart';
import 'package:cartelera/data/repository.dart';
import 'package:cartelera/data/sources/source.dart';
import 'package:cartelera/ui/app_model.dart';
import 'package:cartelera/ui/screens/alerts_screen.dart';
import 'package:cartelera/ui/screens/home_screen.dart';
import 'package:cartelera/ui/theme.dart';
import 'package:cartelera/ui/widgets/film_card.dart';
import 'package:cartelera/ui/widgets/session_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositorio de prueba: el ejemplo del paquete, movido a «hoy» y sin pósters
/// (para no tocar la red), y sin disco.
class _FakeRepo extends CarteleraRepository {
  @override
  Future<void> load() async {
    final raw = jsonDecode(File('assets/sample_snapshot.json').readAsStringSync()) as Map<String, dynamic>;
    final base = Snapshot.fromJson(raw);
    final shift = DateTime.now().difference(DateTime(2026, 11, 17)).inDays;
    snapshot = Snapshot(
      generatedAt: DateTime.now(),
      sources: [
        ...base.sources,
        SourceStatus(id: 'casamerica', name: 'Casa de América', url: 'https://example.com', ok: false, count: 0,
            error: 'Tiempo de espera agotado', at: DateTime.now()),
      ],
      sessions: [
        for (final s in base.sessions)
          Session.fromJson({
            ...s.toJson(),
            'start': DateTime(s.start.year, s.start.month, s.start.day + shift, s.start.hour, s.start.minute)
                .toIso8601String(),
            'poster': null,
            'stale': s.cinema == 'Golem Madrid',
          }),
      ],
    );
    notifyListeners();
  }

  @override
  Future<void> refresh({List<Source>? sources, bool partial = false}) async {}
}

/// El botón de filtros enseña el número de activos (se lee por accesibilidad).
Future<void> expectFilters2(WidgetTester tester) async {
  final h = tester.ensureSemantics();
  await tester.pump();
  expect(find.bySemanticsLabel('Filtros, 2 activos'), findsOneWidget);
  h.dispose();
}

void main() {
  for (final (name, size, scale) in [
    ('móvil', const Size(392, 850), 1.0),
    ('móvil estrecho con letra grande', const Size(340, 700), 1.3),
  ]) {
    testWidgets('pantalla de avisos ($name)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'alerts.films.v1': '{"perfect days":"Perfect Days","una pelicula con un titulo larguisimo de verdad":"Una película con un título larguísimo de verdad"}',
        'alerts.sources.v1': ['academia'],
        'alerts.lastRun.v1': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
        'alerts.lastResult.v1': '2 pases nuevos · 12 de 17 webs leídas',
      });
      final model = AppModel(_FakeRepo());
      await tester.runAsync(model.init);
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AlertsScreen(model: model),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('Vigilando 2 películas y 1 cine'), findsOneWidget);
      expect(find.textContaining('Última comprobación'), findsOneWidget);
      await tester.ensureVisible(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      expect(model.alerts.interval, const Duration(minutes: 30));
      await tester.ensureVisible(find.byTooltip('Dejar de vigilar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dejar de vigilar').first);
      await tester.pumpAndSettle();
      expect(model.alerts.films.length, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
    });
  }

  for (final (name, size, scale) in [
    ('móvil', const Size(392, 850), 1.0),
    ('móvil estrecho con letra grande', const Size(340, 700), 1.3),
  ]) {
    testWidgets('recorrido por las pantallas ($name)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      final model = AppModel(_FakeRepo());
      await tester.runAsync(model.init);
      addTearDown(model.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: HomeScreen(model: model),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Cartelera'), findsOneWidget);
      expect(find.byType(FilmCard), findsWidgets);
      expect(find.textContaining('lectura anterior'), findsOneWidget); // aviso de pases sin confirmar

      // Catálogo: bajar un buen trecho.
      await tester.drag(find.byType(FilmCard).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Agenda.
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionTile), findsWidgets);
      await tester.drag(find.byType(SessionTile).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      // Ficha de película desde la agenda.
      await tester.tap(find.byType(SessionTile).at(2));
      await tester.pumpAndSettle();
      expect(find.textContaining('pase'), findsWidgets);
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -1500));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Atrás'));
      await tester.pumpAndSettle();

      // Filtros: abrir, tocar varios y volver.
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Cuándo'), findsOneWidget);
      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Solo pases especiales'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Solo pases especiales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solo pases especiales'));
      await tester.pumpAndSettle();
      expect(model.filters.onlySpecial, isTrue);
      await tester.scrollUntilVisible(find.text('Cines'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Filmotecas y salas de autor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filmotecas y salas de autor'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Ordenar el catálogo'), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Filtros · 2'), findsOneWidget); // título de la hoja de filtros
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await expectFilters2(tester);
      expect(model.active.map((a) => a.label), ['Hoy', 'Solo especiales']);

      // Quitar un filtro desde su chip.
      await tester.ensureVisible(find.byTooltip('Quitar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar').first);
      await tester.pumpAndSettle();
      expect(model.active.length, 1);

      // Fuentes.
      await tester.tap(find.byTooltip('Fuentes'));
      await tester.pumpAndSettle();
      // La lista sale de las fuentes reales; la que falló enseña su error.
      await tester.scrollUntilVisible(find.text('Tiempo de espera agotado'), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text('Tiempo de espera agotado'), findsOneWidget);

      // Desactivar una fuente la quita de la cartelera y se recuerda.
      final kinepolis = find.text('Kinépolis Ciudad de la Imagen (vía eCartelera)');
      await tester.scrollUntilVisible(kinepolis, 300, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(kinepolis);
      await tester.pumpAndSettle();
      await tester.tap(kinepolis);
      await tester.pumpAndSettle();
      expect(model.isSourceEnabled('ecartelera:kinepolis'), isFalse);
      expect(find.text('Desactivada'), findsOneWidget);
    });
  }
}
