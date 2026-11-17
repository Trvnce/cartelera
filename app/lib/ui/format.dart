// Formato de fechas, precios y versiones en castellano (sin `intl`).

const _weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

/// Días naturales entre dos fechas (a prueba de cambios de hora).
int daysBetween(DateTime from, DateTime to) => (dayOf(to).difference(dayOf(from)).inHours / 24).round();

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _two(int n) => n.toString().padLeft(2, '0');

String fmtTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// «jue 19 nov»
String fmtDate(DateTime d) => '${_weekdaysShort[d.weekday - 1]} ${d.day} ${_monthsShort[d.month - 1]}';

/// «Hoy», «Mañana» o «jue 19» (con mes si no es el actual).
String fmtDayShort(DateTime d, DateTime now) {
  final diff = daysBetween(now, d);
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  final base = '${_weekdaysShort[d.weekday - 1]} ${d.day}';
  return d.month == now.month && d.year == now.year ? base : '$base ${_monthsShort[d.month - 1]}';
}

/// Cabecera de día: «Hoy», «Mañana», «Jueves 19»…
String fmtDayTitle(DateTime d, DateTime now) {
  final diff = daysBetween(now, d);
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  return '${capitalize(_weekdays[d.weekday - 1])} ${d.day}';
}

/// Acompaña a [fmtDayTitle]: «martes 17 de noviembre» o «de noviembre».
String fmtDaySubtitle(DateTime d, DateTime now) {
  final diff = daysBetween(now, d);
  if (diff == 0 || diff == 1) return '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';
  return 'de ${_months[d.month - 1]}';
}

/// «Hoy 18:30», «Mañana 20:00», «jue 19 · 18:30».
String fmtWhen(DateTime d, DateTime now) {
  final day = fmtDayShort(d, now);
  final diff = daysBetween(now, d);
  return diff == 0 || diff == 1 ? '$day ${fmtTime(d)}' : '$day · ${fmtTime(d)}';
}

/// «hoy a las 16:47», «ayer a las 09:05», «el 15 nov a las 12:00».
String fmtUpdated(DateTime at, DateTime now) {
  final diff = daysBetween(at, now);
  final t = fmtTime(at);
  if (diff == 0) return 'hoy a las $t';
  if (diff == 1) return 'ayer a las $t';
  return 'el ${at.day} ${_monthsShort[at.month - 1]} a las $t';
}

/// «8,40 €», «Gratis» si es 0, null si no se conoce.
String? fmtPrice(double? p) {
  if (p == null) return null;
  if (p <= 0) return 'Gratis';
  return '${p.toStringAsFixed(2).replaceAll('.', ',')} €';
}

/// Texto visible de la versión de un pase.
String? versionLabel(String? v) {
  switch (v) {
    case null:
    case '':
      return null;
    case 'VOSE':
      return 'VOSE';
    case 'VO':
      return 'V.O.';
    case 'ES':
      return 'V.O. castellano';
    case 'DOBLADA':
      return 'Doblada';
    default:
      return v;
  }
}

String fmtDuration(int min) => min >= 60 ? '${min ~/ 60} h ${_two(min % 60)} min' : '$min min';
