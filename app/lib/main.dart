import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/alerts.dart';
import 'data/repository.dart';
import 'ui/app_model.dart';
import 'ui/screens/film_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/poster_backdrop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // De borde a borde: la app pinta bajo las barras del sistema.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  warmUpGrain(); // textura de grano del fondo de las fichas
  final model = AppModel(CarteleraRepository());
  model.init(); // carga lo guardado y, si está viejo, actualiza sola
  runApp(CarteleraApp(model: model));
  if (AppModel.alertsSupported) _initAlerts(model);
}

final _navigator = GlobalKey<NavigatorState>();

/// Notificaciones de pases nuevos: al pulsar una se abre la ficha de esa película.
Future<void> _initAlerts(AppModel model) async {
  final launchedWith = await AlertNotifier.init(onOpen: (k) => _openFilm(model, k));
  if (launchedWith != null) _openFilm(model, launchedWith);
}

void _openFilm(AppModel model, String filmKey) {
  if (!model.ready) {
    // Arranque en frío desde la notificación: espera a tener la cartelera cargada.
    void wait() {
      if (!model.ready) return;
      model.removeListener(wait);
      _openFilm(model, filmKey);
    }
    model.addListener(wait);
    return;
  }
  _navigator.currentState?.push(MaterialPageRoute<void>(builder: (_) => FilmScreen(model: model, filmKey: filmKey)));
}

/// Vista previa del diseño de iPhone en un Android:
/// `flutter build apk --dart-define=FORCE_IOS=true --android-project-arg=iosPreview=true`.
/// Toda la interfaz decide la plataforma con `Theme.of(context).platform` (ver ui/adaptive.dart).
const forceIos = bool.fromEnvironment('FORCE_IOS');

class CarteleraApp extends StatelessWidget {
  const CarteleraApp({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartelera',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      theme: forceIos ? buildTheme().copyWith(platform: TargetPlatform.iOS) : buildTheme(),
      darkTheme: forceIos ? buildTheme().copyWith(platform: TargetPlatform.iOS) : buildTheme(),
      // En la vista previa, también el rebote del scroll al estilo iOS.
      scrollBehavior: forceIos ? const _IosScrollBehavior() : null,
      themeMode: ThemeMode.dark,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Exigido por cupertino_native_better: oculta los controles nativos bajo hojas y pantallas nuevas.
      navigatorObservers: [CNTabBarRouteObserver()],
      home: HomeScreen(model: model),
    );
  }
}

class _IosScrollBehavior extends MaterialScrollBehavior {
  const _IosScrollBehavior();

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.iOS;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
