import 'package:flutter/material.dart';

import '../adaptive.dart';
import '../../data/model.dart';
import '../app_model.dart';
import '../format.dart';
import '../theme.dart';
import 'catalog.dart';
import 'cinema_groups.dart';
import 'filter_state.dart';

/// Apartado de filtros: una pantalla propia, por secciones, que aplica los
/// cambios al momento y enseña abajo cuántos pases quedan.
class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key, required this.model});

  final AppModel model;

  static Future<void> open(BuildContext context, AppModel model) => Navigator.of(context).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => FiltersScreen(model: model)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final f = model.filters;
        final activeCount = model.active.length;
        final bottom = MediaQuery.paddingOf(context).bottom;
        return Scaffold(
          appBar: adaptiveBar(
            context,
            leadingClose: true,
            title: activeCount == 0 ? 'Filtros' : 'Filtros · $activeCount',
            textAction: BarTextAction('Restablecer', activeCount == 0 ? null : () => model.setFilters(f.cleared())),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _WhenSection(model: model),
              const Divider(),
              _TypeSection(model: model),
              const Divider(),
              _VersionSection(model: model),
              const Divider(),
              _CinemaSection(model: model),
              const Divider(),
              _PriceSection(model: model),
              const Divider(),
              _SortSection(model: model),
            ],
          ),
          bottomNavigationBar: Material(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  model.visible.isEmpty
                      ? 'Ningún pase con estos filtros'
                      : 'Ver ${plural(model.visible.length, 'pase', 'pases')} · '
                          '${plural(model.films.length, 'película', 'películas')}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.hint, this.trailing, required this.children, this.padded = true});

  final String title;
  final String? hint;
  final Widget? trailing;
  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      if (hint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(hint!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final c in children)
            padded ? Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: c) : c,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted),
        ),
      );
}

Set<T> _toggle<T>(Set<T> set, T v) => set.contains(v) ? ({...set}..remove(v)) : {...set, v};

// ───────────────────────── Cuándo ─────────────────────────

class _WhenSection extends StatelessWidget {
  const _WhenSection({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final now = model.now;
    final days = <DateTime>[];
    for (final s in model.upcoming) {
      final d = dayOf(s.start);
      if (days.isEmpty || days.last != d) days.add(d);
    }
    const quick = [WhenFilter.all, WhenFilter.today, WhenFilter.tomorrow, WhenFilter.weekend, WhenFilter.next7];
    return _Section(
      title: 'Cuándo',
      padded: false,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final w in quick)
                ChoiceChip(
                  label: Text(whenLabel(w)),
                  selected: f.when == w,
                  showCheckmark: false,
                  onSelected: (_) => model.setFilters(f.copyWith(when: w, date: null)),
                ),
            ],
          ),
        ),
        if (days.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _Label('O un día concreto')),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = days[i];
                final selected = f.when == WhenFilter.date && f.date == d;
                return _DayCell(
                  day: d,
                  now: now,
                  selected: selected,
                  onTap: () => model.setFilters(
                    selected ? f.copyWith(when: WhenFilter.all, date: null) : f.copyWith(when: WhenFilter.date, date: d),
                  ),
                );
              },
            ),
          ),
        ],
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _Label('Franja horaria')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final b in TimeBand.values)
                FilterChip(
                  label: Text('${bandLabel(b)} · ${bandHint(b)}'),
                  selected: f.bands.contains(b),
                  onSelected: (_) => model.setFilters(f.copyWith(bands: _toggle(f.bands, b))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.now, required this.selected, required this.onTap});
  final DateTime day;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.onAmber : AppColors.cream;
    final weekend = day.weekday >= DateTime.saturday;
    return Semantics(
      button: true,
      selected: selected,
      label: fmtDate(day),
      child: Material(
        color: selected ? AppColors.amber : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 56,
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    daysBetween(now, day) == 0 ? 'hoy' : weekdayShort(day),
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? fg : (weekend ? AppColors.amber : AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Tipo de pase ─────────────────────────

class _TypeSection extends StatelessWidget {
  const _TypeSection({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final counts = <String, int>{};
    var special = 0, academics = 0;
    for (final s in model.upcoming) {
      if (s.academicsOnly) academics++;
      if (s.isSpecial) special++;
      for (final t in s.tags) {
        if (Session.specialTags.contains(t)) counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final tags = sortTags({...counts.keys, ...f.tags});
    return _Section(
      title: 'Tipo de pase',
      padded: false,
      children: [
        AdaptiveSwitchTile(
          secondary: const Icon(Icons.star_rounded, color: AppColors.amber),
          title: const Text('Solo pases especiales'),
          subtitle: Text('Ciclos, festivales, coloquios, clásicos… ($special)'),
          value: f.onlySpecial,
          onChanged: (v) => model.setFilters(f.copyWith(onlySpecial: v)),
        ),
        if (tags.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _Label('Con alguna de estas etiquetas')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final t in tags)
                  FilterChip(
                    label: Text('${capitalize(t)} · ${counts[t] ?? 0}'),
                    selected: f.tags.contains(t),
                    onSelected: (_) => model.setFilters(f.copyWith(tags: _toggle(f.tags, t))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        AdaptiveSwitchTile(
          secondary: const Icon(Icons.badge_outlined),
          title: const Text('Mostrar pases solo para académicos'),
          subtitle: Text('Sesiones cerradas de la Academia de Cine ($academics)'),
          value: f.showAcademics,
          onChanged: (v) => model.setFilters(f.copyWith(showAcademics: v)),
        ),
      ],
    );
  }
}

// ───────────────────────── Versión ─────────────────────────

class _VersionSection extends StatelessWidget {
  const _VersionSection({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final counts = <VersionFilter, int>{};
    for (final s in model.upcoming) {
      final v = versionOf(s);
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return _Section(
      title: 'Versión',
      hint: f.versions.isEmpty ? 'Todas' : null,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final v in VersionFilter.values)
              FilterChip(
                label: Text('${versionFilterLabel(v)} · ${counts[v] ?? 0}'),
                selected: f.versions.contains(v),
                onSelected: (_) => model.setFilters(f.copyWith(versions: _toggle(f.versions, v))),
              ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── Cines ─────────────────────────

class _CinemaSection extends StatelessWidget {
  const _CinemaSection({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final all = model.cinemas;
    final counts = <String, int>{};
    for (final s in model.upcoming) {
      counts[s.cinema] = (counts[s.cinema] ?? 0) + 1;
    }
    final groups = groupCinemas(all);
    final selected = all.where((c) => !f.excludedCinemas.contains(c)).length;
    return _Section(
      title: 'Cines',
      hint: selected == all.length ? 'Todos (${all.length})' : '$selected de ${all.length}',
      padded: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: selected == all.length ? null : () => model.setFilters(f.copyWith(excludedCinemas: const {})),
            child: const Text('Todos'),
          ),
          TextButton(
            onPressed: selected == 0 ? null : () => model.setFilters(f.copyWith(excludedCinemas: all.toSet())),
            child: const Text('Ninguno'),
          ),
        ],
      ),
      children: [
        for (final e in groups.entries) _CinemaGroupTile(model: model, group: e.key, cinemas: e.value, counts: counts),
      ],
    );
  }
}

class _CinemaGroupTile extends StatelessWidget {
  const _CinemaGroupTile({required this.model, required this.group, required this.cinemas, required this.counts});
  final AppModel model;
  final CinemaGroup group;
  final List<String> cinemas;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final on = cinemas.where((c) => !f.excludedCinemas.contains(c)).length;
    final bool? value = on == cinemas.length ? true : (on == 0 ? false : null);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey('cinema-group-${group.name}'),
        tilePadding: const EdgeInsets.only(left: 4, right: 16),
        leading: Checkbox(
          tristate: true,
          value: value,
          onChanged: (_) {
            // Todo marcado → se desmarca el grupo; si no, se marca entero.
            final next = {...f.excludedCinemas};
            if (value == true) {
              next.addAll(cinemas);
            } else {
              next.removeAll(cinemas);
            }
            model.setFilters(f.copyWith(excludedCinemas: next));
          },
        ),
        title: Text(cinemaGroupLabel(group), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(
          on == cinemas.length ? plural(cinemas.length, 'cine', 'cines') : '$on de ${cinemas.length}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        children: [
          for (final c in cinemas)
            CheckboxListTile.adaptive(
              contentPadding: const EdgeInsets.only(left: 4, right: 16),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(c),
              secondary: Text('${counts[c] ?? 0}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              value: !f.excludedCinemas.contains(c),
              onChanged: (_) => model.setFilters(f.copyWith(excludedCinemas: _toggle(f.excludedCinemas, c))),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Precio ─────────────────────────

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.model});
  final AppModel model;

  static const _top = 12.0; // el tope del deslizador significa «sin límite»

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    final value = (f.maxPrice ?? _top).clamp(0.0, _top);
    final label = f.maxPrice == null
        ? 'Sin límite'
        : f.maxPrice! <= 0
            ? 'Solo gratis'
            : 'Hasta ${fmtPrice(f.maxPrice)}';
    return _Section(
      title: 'Precio máximo',
      hint: label,
      padded: false,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Slider(
            value: value,
            min: 0,
            max: _top,
            divisions: 24,
            label: label,
            semanticFormatterCallback: (v) => v >= _top ? 'Sin límite' : fmtPrice(v) ?? '',
            onChanged: (v) => model.setFilters(f.copyWith(maxPrice: v >= _top ? null : v)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Los pases sin precio publicado se muestran siempre.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Orden ─────────────────────────

class _SortSection extends StatelessWidget {
  const _SortSection({required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    return _Section(
      title: 'Ordenar el catálogo',
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final s in CatalogSort.values)
              ChoiceChip(
                label: Text(sortLabel(s)),
                selected: f.sort == s,
                showCheckmark: false,
                onSelected: (_) => model.setFilters(f.copyWith(sort: s)),
              ),
          ],
        ),
      ],
    );
  }
}
