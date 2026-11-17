import 'dart:io' show Platform;

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'theme.dart';

/// Piezas que cambian según la plataforma:
/// - **iPhone real** ([useNativeIos]): controles de UIKit de verdad vía
///   cupertino_native_better (barra de pestañas, botones de cristal, menús e
///   interruptores; Liquid Glass en iOS 26+, clásicos por debajo).
/// - **Aspecto iOS dibujado por Flutter** ([isCupertino] sin [useNativeIos]): la vista
///   previa en Android y los tests.
/// - **Android**: Material 3 tal cual.
bool isCupertino(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Solo en un iPhone de verdad: los controles nativos son vistas de UIKit incrustadas
/// y no existen en Android ni en los tests.
final bool useNativeIos = !kIsWeb && Platform.isIOS;

/// Una acción de barra superior: icono Material en Android, icono SF en iOS.
class BarAction {
  const BarAction({required this.icon, required this.cupertinoIcon, required this.tooltip, this.onPressed, this.busy = false, this.color, this.sfSymbol});
  final IconData icon;
  final IconData cupertinoIcon;
  final String? sfSymbol; // nombre del SF Symbol para el botón nativo de iOS
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy; // muestra un indicador de actividad en lugar del icono
  final Color? color;
}

/// Acción de texto («Restablecer», «Cancelar»).
class BarTextAction {
  const BarTextAction(this.label, this.onPressed);
  final String label;
  final VoidCallback? onPressed;
}

/// Barra superior adaptativa.
///
/// - [title]/[subtitle]: título (y línea secundaria opcional).
/// - [leadingClose]: pantalla modal (filtros) → «Cerrar» en lugar de «atrás».
/// - En iOS, si no hay [leading] ni [leadingClose], la barra pone sola la flecha «‹» de volver.
PreferredSizeWidget adaptiveBar(
  BuildContext context, {
  String? title,
  String? subtitle,
  Widget? titleWidget,
  bool leadingClose = false,
  Widget? leading,
  List<BarAction> actions = const [],
  BarTextAction? textAction,
  bool largeTitle = false,
}) {
  if (isCupertino(context)) {
    final middle = titleWidget ??
        (subtitle == null
            ? Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.cream)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w400)),
                ],
              ));
    final trailing = <Widget>[
      if (textAction != null)
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(44, 44),
          onPressed: textAction.onPressed,
          child: Text(textAction.label),
        ),
      for (final a in actions)
        if (useNativeIos && a.sfSymbol != null && !a.busy)
          // Botón de cristal nativo (Liquid Glass en iOS 26+).
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: CNButton.icon(
              icon: CNSymbol(a.sfSymbol!, size: 18, color: a.color),
              onPressed: a.onPressed,
              enabled: a.onPressed != null,
              semanticLabel: a.tooltip,
              config: const CNButtonConfig(style: CNButtonStyle.glass, minHeight: 38, width: 38),
            ),
          )
        else
        Semantics(
          label: a.tooltip,
          button: true,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(44, 44),
            onPressed: a.onPressed,
            child: a.busy
                ? const CupertinoActivityIndicator(radius: 9)
                : Icon(a.cupertinoIcon, size: 23, color: a.color),
          ),
        ),
    ];
    return CupertinoNavigationBar(
      middle: middle,
      leading: leading ??
          (leadingClose
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                )
              : null),
      previousPageTitle: 'Atrás',
      trailing: trailing.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: trailing),
      border: const Border(bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.0)),
    );
  }

  return AppBar(
    titleSpacing: 16,
    leading: leading ??
        (leadingClose
            ? IconButton(icon: const Icon(Icons.close), tooltip: 'Cerrar', onPressed: () => Navigator.of(context).pop())
            : null),
    title: titleWidget ??
        (subtitle == null
            ? Text(title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.muted)),
                ],
              )),
    actions: [
      if (textAction != null) TextButton(onPressed: textAction.onPressed, child: Text(textAction.label)),
      for (final a in actions)
        IconButton(
          icon: a.busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
              : Icon(a.icon, color: a.color),
          tooltip: a.tooltip,
          onPressed: a.busy ? null : a.onPressed,
        ),
      const SizedBox(width: 4),
    ],
  );
}

/// Una pestaña de la barra inferior.
class TabItem {
  const TabItem({required this.label, required this.icon, required this.selectedIcon, required this.cupertinoIcon,
      required this.cupertinoSelectedIcon, required this.sfSymbol, required this.sfSymbolSelected, this.badge});
  final String label;
  final IconData icon, selectedIcon, cupertinoIcon, cupertinoSelectedIcon;
  final String sfSymbol, sfSymbolSelected; // para la barra nativa de iOS
  final String? badge;
}

/// Barra de pestañas inferior: CupertinoTabBar en iOS, NavigationBar en Android.
Widget adaptiveTabBar(BuildContext context,
    {required int index, required ValueChanged<int> onTap, required List<TabItem> items}) {
  Widget badged(Widget icon, String? badge) =>
      badge == null ? icon : Badge(label: Text(badge), backgroundColor: AppColors.amber, textColor: AppColors.onAmber, child: icon);

  if (useNativeIos) {
    // UITabBar nativa: Liquid Glass flotante en iOS 26+, clásica por debajo.
    return CNTabBar(
      currentIndex: index,
      onTap: onTap,
      tint: AppColors.amber,
      items: [
        for (final t in items)
          CNTabBarItem(
            label: t.label,
            icon: CNSymbol(t.sfSymbol),
            activeIcon: CNSymbol(t.sfSymbolSelected),
            badge: t.badge,
          ),
      ],
    );
  }
  if (isCupertino(context)) {
    return CupertinoTabBar(
      currentIndex: index,
      onTap: onTap,
      activeColor: AppColors.amber,
      inactiveColor: AppColors.muted,
      backgroundColor: const Color(0xE6191715),
      border: const Border(top: BorderSide(color: Color(0x33FFFFFF), width: 0.0)),
      items: [
        for (final t in items)
          BottomNavigationBarItem(
            icon: badged(Icon(t.cupertinoIcon), t.badge),
            activeIcon: badged(Icon(t.cupertinoSelectedIcon), t.badge),
            label: t.label,
          ),
      ],
    );
  }
  return NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onTap,
    destinations: [
      for (final t in items)
        NavigationDestination(icon: badged(Icon(t.icon), t.badge), selectedIcon: Icon(t.selectedIcon), label: t.label),
    ],
  );
}

/// Elegir una opción: hoja de acción de iOS o menú emergente en Android.
Future<T?> showAdaptiveChoice<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
  T? selected,
}) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final v in values)
            CupertinoActionSheetAction(
              isDefaultAction: v == selected,
              onPressed: () => Navigator.of(ctx).pop(v),
              child: Text(v == selected ? '${label(v)}  ✓' : label(v)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
          ),
          for (final v in values)
            ListTile(
              title: Text(label(v)),
              trailing: v == selected ? const Icon(Icons.check, color: AppColors.amber) : null,
              onTap: () => Navigator.of(ctx).pop(v),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Fila con interruptor: UISwitch nativo en iPhone, adaptativo (aspecto iOS o Material)
/// en el resto.
class AdaptiveSwitchTile extends StatelessWidget {
  const AdaptiveSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.secondary,
    required this.value,
    required this.onChanged,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!useNativeIos) {
      return SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: secondary,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      );
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: secondary,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: CNSwitch(value: value, onChanged: onChanged, color: AppColors.amber),
    );
  }
}
