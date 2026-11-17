// Contrato de datos de la app. La interfaz SOLO depende de este fichero y de
// `CarteleraRepository` (lib/data/repository.dart).

/// Un pase de cine, venga de la fuente que venga.
class Session {
  Session({
    required this.source,
    required this.cinema,
    required this.title,
    required this.start,
    this.room,
    this.version,
    this.director,
    this.year,
    this.durationMin,
    this.cycle,
    this.section,
    List<String>? tags,
    this.note,
    this.priceEur,
    this.priceNote,
    this.ticketUrl,
    this.infoUrl,
    this.imdbId,
    this.poster,
    this.rawTitle,
    this.stale = false,
  }) : tags = tags ?? [];

  final String source; // id del lector («renoir», «cineteca»…)
  final String cinema; // nombre visible del cine
  String title;
  final DateTime start; // hora local de Madrid
  final String? room; // «Sala 1», «Sala Azcona»…
  final String? version; // 'VOSE' · 'VO' · 'ES' (original en castellano) · 'DOBLADA' · null
  String? director;
  int? year;
  final int? durationMin;
  String? cycle; // ciclo, festival o programa
  final String? section; // sección del cine (Cineteca)
  List<String> tags; // coloquio, presentación, preestreno, 35 mm, 70 mm, restaurada,
  // festival, pase especial, clásico, reestreno, ciclo, estreno, solo académicos
  final String? note; // texto libre del cine
  final double? priceEur; // precio general; null = se ve en la compra
  final String? priceNote;
  final String? ticketUrl;
  final String? infoUrl;
  final String? imdbId;
  String? poster;
  final String? rawTitle;
  bool stale; // dato de la última lectura buena: la fuente falló hoy

  /// Etiquetas que hacen «especial» un pase.
  static const specialTags = {
    'coloquio', 'presentación', 'preestreno', 'música en directo', '35 mm', '70 mm',
    'restaurada', 'festival', 'pase especial', 'clásico', 'reestreno', 'ciclo',
  };

  bool get isSpecial => tags.any(specialTags.contains);
  bool get academicsOnly => tags.contains('solo académicos');
  bool get isOriginalVersion => version == 'VOSE' || version == 'VO';

  /// Identidad estable del pase.
  String get key => '$cinema|${room ?? ''}|${start.toIso8601String()}|${normTitle(title)}';

  /// Clave para agrupar el mismo título entre cines.
  String get filmKey => normTitle(title);

  Map<String, dynamic> toJson() => {
        'source': source, 'cinema': cinema, 'title': title, 'start': start.toIso8601String(),
        'room': room, 'version': version, 'director': director, 'year': year,
        'duration_min': durationMin, 'cycle': cycle, 'section': section, 'tags': tags,
        'note': note, 'price_eur': priceEur, 'price_note': priceNote, 'ticket_url': ticketUrl,
        'info_url': infoUrl, 'imdb_id': imdbId, 'poster': poster, 'raw_title': rawTitle,
        'stale': stale,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        source: j['source'] as String,
        cinema: j['cinema'] as String,
        title: j['title'] as String,
        start: DateTime.parse(j['start'] as String),
        room: j['room'] as String?,
        version: j['version'] as String?,
        director: j['director'] as String?,
        year: (j['year'] as num?)?.toInt(),
        durationMin: (j['duration_min'] as num?)?.toInt(),
        cycle: j['cycle'] as String?,
        section: j['section'] as String?,
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        note: j['note'] as String?,
        priceEur: (j['price_eur'] as num?)?.toDouble(),
        priceNote: j['price_note'] as String?,
        ticketUrl: j['ticket_url'] as String?,
        infoUrl: j['info_url'] as String?,
        imdbId: j['imdb_id'] as String?,
        poster: j['poster'] as String?,
        rawTitle: j['raw_title'] as String?,
        stale: j['stale'] as bool? ?? false,
      );
}

/// Estado de una fuente en la última actualización.
class SourceStatus {
  SourceStatus({
    required this.id,
    required this.name,
    required this.url,
    required this.ok,
    required this.count,
    this.error,
    required this.at,
  });

  final String id;
  final String name;
  final String url;
  final bool ok;
  final int count;
  final String? error;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': url, 'ok': ok, 'count': count, 'error': error, 'at': at.toIso8601String()};

  factory SourceStatus.fromJson(Map<String, dynamic> j) => SourceStatus(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        ok: j['ok'] as bool,
        count: (j['count'] as num).toInt(),
        error: j['error'] as String?,
        at: DateTime.parse(j['at'] as String),
      );
}

/// Todo lo leído en una actualización.
class Snapshot {
  Snapshot({required this.generatedAt, required this.sources, required this.sessions});

  final DateTime generatedAt;
  final List<SourceStatus> sources;
  final List<Session> sessions;

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt.toIso8601String(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        generatedAt: DateTime.parse(j['generated_at'] as String),
        sources: (j['sources'] as List).map((e) => SourceStatus.fromJson(e as Map<String, dynamic>)).toList(),
        sessions: (j['sessions'] as List).map((e) => Session.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Progreso de una actualización en curso (para la barra / el listado de fuentes).
class RefreshProgress {
  RefreshProgress({required this.total, required this.done, required this.running, required this.finished});
  final int total;
  final int done;
  final List<String> running; // nombres de las fuentes que se están leyendo
  final List<SourceStatus> finished;
  double get fraction => total == 0 ? 0 : done / total;
}

/// Minúsculas sin tildes ni signos, para comparar títulos.
String normTitle(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const to = 'aaaaaeeeeiiiiooooouuuuncaaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    final ch = i >= 0 ? to[i] : c.toLowerCase();
    b.write(RegExp(r'[a-z0-9]').hasMatch(ch) ? ch : ' ');
  }
  return b.toString().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).join(' ');
}
