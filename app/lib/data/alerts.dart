import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'engine.dart';
import 'model.dart';
import 'sources/source.dart';

/// Avisos de pases nuevos (solo Android).
///
/// - Se vigilan **películas** (por `Session.filmKey`) y **fuentes** (cada web de un cine,
///   por `Source.id`).
/// - Una tarea periódica de WorkManager relee las webs necesarias cada [AlertPrefs.interval]
///   (Android no deja bajar de 15 minutos y, con la batería, puede espaciarla más), compara
///   con la cartelera guardada y avisa de los pases que no estaban.
/// - Lo mismo se comprueba tras cada actualización hecha a mano en la app.
class AlertPrefs {
  AlertPrefs({Map<String, String>? films, Set<String>? sources, this.interval = defaultInterval})
      : films = films ?? {},
        sources = sources ?? {};

  /// filmKey → título visible (para enseñarlo en la lista aunque ya no esté en cartel).
  final Map<String, String> films;

  /// Ids de las fuentes vigiladas.
  final Set<String> sources;

  final Duration interval;

  static const defaultInterval = Duration(hours: 1);
  static const intervals = [Duration(minutes: 15), Duration(minutes: 30), Duration(hours: 1), Duration(hours: 3), Duration(hours: 6)];

  bool get isEmpty => films.isEmpty && sources.isEmpty;

  static const _kFilms = 'alerts.films.v1';
  static const _kSources = 'alerts.sources.v1';
  static const _kInterval = 'alerts.interval.min.v1';
  static const kLastRun = 'alerts.lastRun.v1';
  static const kLastResult = 'alerts.lastResult.v1';

  static AlertPrefs read(SharedPreferences p) {
    Map<String, String> films = {};
    try {
      final raw = p.getString(_kFilms);
      if (raw != null) films = (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {}
    final min = p.getInt(_kInterval);
    return AlertPrefs(
      films: films,
      sources: {...?p.getStringList(_kSources)},
      interval: min == null ? defaultInterval : Duration(minutes: min),
    );
  }

  Future<void> write(SharedPreferences p) async {
    await p.setString(_kFilms, jsonEncode(films));
    await p.setStringList(_kSources, sources.toList()..sort());
    await p.setInt(_kInterval, interval.inMinutes);
  }

  AlertPrefs copyWith({Map<String, String>? films, Set<String>? sources, Duration? interval}) =>
      AlertPrefs(films: films ?? this.films, sources: sources ?? this.sources, interval: interval ?? this.interval);

  /// Fuentes que hay que leer para comprobar los avisos: las vigiladas y, si se vigila
  /// alguna película, todas las activas (puede aparecer en cualquier cine).
  List<Source> sourcesToRead(Set<String> disabled) => [
        for (final s in allSources)
          if (!disabled.contains(s.id) && (films.isNotEmpty || sources.contains(s.id))) s,
      ];
}

/// Pases de [fresh] que no estaban en [prev] y que interesan según [prefs]. Sin [prev]
/// (primera lectura) no hay nada «nuevo». Se ignoran los que ya han empezado, los
/// heredados de una lectura anterior y los «solo para académicos».
List<Session> newAlertMatches(Snapshot? prev, Snapshot fresh, AlertPrefs prefs, {DateTime? now}) {
  if (prev == null || prefs.isEmpty) return const [];
  final t = now ?? DateTime.now();
  // Una fuente que falló en la lectura anterior no tenía sus pases: no se avisa de todo
  // lo suyo como si fuera nuevo al volver.
  final failedBefore = {for (final s in prev.sources) if (!s.ok) s.id};
  final readBefore = {for (final s in prev.sources) s.id};
  final seen = {for (final s in prev.sessions) s.key};
  return [
    for (final s in fresh.sessions)
      if (!s.stale &&
          !s.academicsOnly &&
          s.start.isAfter(t) &&
          readBefore.contains(s.source) &&
          !failedBefore.contains(s.source) &&
          !seen.contains(s.key) &&
          (prefs.films.containsKey(s.filmKey) || prefs.sources.contains(s.source)))
        s,
  ];
}

/// Notificaciones locales: un aviso por película con sus pases nuevos.
abstract final class AlertNotifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'new_sessions',
    'Pases nuevos',
    channelDescription: 'Pases nuevos de las películas y los cines que vigilas',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_stat_cartelera',
    color: Color(0xFFF5B841),
    groupKey: 'new_sessions',
  );

  /// [onOpen] recibe el filmKey de la notificación pulsada (con la app abierta o en
  /// segundo plano). Devuelve el filmKey con el que se abrió la app, si fue por un aviso.
  static Future<String?> init({ValueChanged<String>? onOpen}) async {
    if (!Platform.isAndroid) return null;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_cartelera')),
      onDidReceiveNotificationResponse: onOpen == null
          ? null
          : (r) {
              final p = r.payload;
              if (p != null && p.isNotEmpty) onOpen(p);
            },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) return launch!.notificationResponse?.payload;
    return null;
  }

  /// Pide el permiso de notificaciones (Android 13+). true si está concedido.
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    if (!_ready) await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> notify(List<Session> found) async {
    if (found.isEmpty || !Platform.isAndroid) return;
    if (!_ready) await init();
    final byFilm = <String, List<Session>>{};
    for (final s in found) {
      (byFilm[s.filmKey] ??= []).add(s);
    }
    for (final e in byFilm.entries) {
      final list = e.value..sort((a, b) => a.start.compareTo(b.start));
      final first = list.first;
      final when = _fmt(first.start);
      final more = list.length > 1 ? ' (+${list.length - 1} más)' : '';
      await _plugin.show(
        id: e.key.hashCode & 0x7fffffff,
        title: list.length == 1 ? 'Pase nuevo: ${first.title}' : '${list.length} pases nuevos: ${first.title}',
        body: '${first.cinema} · $when$more',
        notificationDetails: const NotificationDetails(android: _channel),
        payload: e.key,
      );
    }
  }

  static const _days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static String _fmt(DateTime d) =>
      '${_days[d.weekday - 1]} ${d.day}/${d.month}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// La tarea periódica de WorkManager.
abstract final class AlertScheduler {
  static const _unique = 'cartelera.alerts';
  static const _task = 'check-new-sessions';
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(alertsCallbackDispatcher);
    _initialized = true;
  }

  /// Programa (o reprograma con la nueva frecuencia) la comprobación, o la quita si no
  /// se vigila nada.
  static Future<void> sync(AlertPrefs prefs) async {
    if (!Platform.isAndroid) return;
    await _init();
    if (prefs.isEmpty) {
      await Workmanager().cancelByUniqueName(_unique);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _unique,
      _task,
      frequency: prefs.interval,
      initialDelay: const Duration(minutes: 2),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }
}

/// Punto de entrada del isolate de segundo plano.
@pragma('vm:entry-point')
void alertsCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final result = await runAlertCheck();
      final p = await SharedPreferences.getInstance();
      await p.setString(AlertPrefs.kLastRun, DateTime.now().toIso8601String());
      await p.setString(AlertPrefs.kLastResult, result);
      return true;
    } catch (e) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(AlertPrefs.kLastRun, DateTime.now().toIso8601String());
        await p.setString(AlertPrefs.kLastResult, 'Error: $e');
      } catch (_) {}
      return false; // WorkManager lo reintentará
    }
  });
}

/// Fichero de la cartelera guardada (el mismo que usa [CarteleraRepository]).
Future<File> snapshotFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/cartelera.json');
}

/// Una comprobación completa en segundo plano: lee lo necesario, avisa de lo nuevo y
/// guarda la cartelera mezclada para que la app abra ya al día. Devuelve un resumen.
Future<String> runAlertCheck() async {
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final prefs = AlertPrefs.read(p);
  if (prefs.isEmpty) return 'Nada que vigilar';
  final disabled = {...?p.getStringList('sources.disabled.v1')};
  final list = prefs.sourcesToRead(disabled);
  if (list.isEmpty) return 'Ninguna fuente activa que leer';

  final f = await snapshotFile();
  final prev = await f.exists()
      ? Snapshot.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>)
      : null;
  final fresh = await refreshAll(previous: prev, sources: list, onProgress: (_) {});
  final found = newAlertMatches(prev, fresh, prefs);
  final merged = prev == null ? fresh : mergePartialSnapshot(prev, fresh);
  await f.writeAsString(jsonEncode(merged.toJson()));
  await AlertNotifier.notify(found);
  final ok = fresh.sources.where((s) => s.ok).length;
  return '${found.length} ${found.length == 1 ? 'pase nuevo' : 'pases nuevos'} · $ok de ${list.length} webs leídas';
}

/// Lectura parcial sobre la cartelera anterior: lo de las fuentes recién leídas sustituye
/// a lo suyo de antes; el resto se queda como estaba. Si se han leído todas las fuentes
/// que había, la fecha pasa a ser la de esta lectura.
Snapshot mergePartialSnapshot(Snapshot prev, Snapshot fresh) {
  final ids = {for (final f in fresh.sources) f.id};
  final sessions = [
    for (final s in prev.sessions)
      if (!ids.contains(s.source)) s,
    ...fresh.sessions,
  ]..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.cinema.compareTo(b.cinema);
    });
  final order = {for (var i = 0; i < allSources.length; i++) allSources[i].id: i};
  final statuses = [
    for (final s in prev.sources)
      if (!ids.contains(s.id)) s,
    ...fresh.sources,
  ]..sort((a, b) => (order[a.id] ?? 99).compareTo(order[b.id] ?? 99));
  final all = prev.sources.every((s) => ids.contains(s.id));
  return Snapshot(generatedAt: all ? fresh.generatedAt : prev.generatedAt, sources: statuses, sessions: sessions);
}
