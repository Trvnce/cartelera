// Cartelera de Madrid — lee window.CARTELERA (generado por `python -m cartelera.run`).
(() => {
  const D = window.CARTELERA || { sessions: [], sources: [] };
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const norm = (s) => String(s || '').normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase();
  const SPECIAL = new Set(['coloquio', 'presentación', 'preestreno', 'música en directo', '35 mm', '70 mm',
    'restaurada', 'festival', 'pase especial', 'clásico', 'reestreno', 'ciclo']);

  // ---------- estado (lo que se recuerda entre visitas, en este navegador) ----------
  const saved = (() => { try { return JSON.parse(localStorage.getItem('cartelera') || '{}'); } catch { return {}; } })();
  const S = {
    view: saved.view || 'dia',
    range: saved.range || '7',
    special: !!saved.special,
    version: saved.version || 'todas',
    maxprice: saved.maxprice || '',
    academicos: !!saved.academicos,
    off: new Set(saved.off || []),          // cines desmarcados
    q: '',
    openFilms: new Set(),                   // tarjetas con todos los pases desplegados
  };
  const save = () => { try { localStorage.setItem('cartelera', JSON.stringify({ ...S, off: [...S.off], q: undefined, openFilms: undefined })); } catch {} };

  const now = new Date();
  const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const today = ymd(now);
  const addDays = (n) => { const d = new Date(now); d.setDate(d.getDate() + n); return ymd(d); };
  const parse = (s) => new Date(s.slice(0, 4), s.slice(5, 7) - 1, s.slice(8, 10), s.slice(11, 13), s.slice(14, 16));
  const DAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  const MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  const dayLabel = (s) => {
    const d = parse(s + 'T00:00');
    const rel = s === today ? 'Hoy' : s === addDays(1) ? 'Mañana' : DAYS[d.getDay()][0].toUpperCase() + DAYS[d.getDay()].slice(1);
    return `${rel} <small>${DAYS[d.getDay()]} ${d.getDate()} de ${MONTHS[d.getMonth()]}</small>`;
  };
  const eur = (v) => v == null ? '' : v.toFixed(2).replace('.', ',') + ' €';

  const sessions = D.sessions
    .filter((s) => parse(s.start) >= new Date(now.getTime() - 15 * 60e3))   // lo que empezó hace >15 min, fuera
    .map((s) => ({ ...s, day: s.start.slice(0, 10), hay: norm([s.title, s.raw_title, s.director, s.cycle, s.section, s.cinema, (s.tags || []).join(' ')].join(' ')) }));

  // ---------- rangos de fecha ----------
  const weekend = (() => {  // viernes a domingo de esta semana (o el que viene si ya pasó)
    const d = new Date(now); const wd = d.getDay();
    const toFri = wd === 0 ? -2 : wd === 6 ? -1 : 5 - wd;
    const fri = new Date(d); fri.setDate(d.getDate() + toFri);
    const sun = new Date(fri); sun.setDate(fri.getDate() + 2);
    return [ymd(fri) < today ? today : ymd(fri), ymd(sun)];
  })();
  const RANGES = {
    hoy: ['Hoy', [today, today]],
    manana: ['Mañana', [addDays(1), addDays(1)]],
    finde: ['Este finde', weekend],
    '7': ['7 días', [today, addDays(6)]],
    todo: ['Todo', [today, '9999']],
  };

  // ---------- controles ----------
  $('dates').innerHTML = Object.entries(RANGES).map(([k, [l]]) => `<button class="chip" data-range="${k}">${l}</button>`).join('');
  const VERS = { todas: 'Todas las versiones', vo: 'VOSE / VO', doblada: 'Doblada' };
  $('versions').innerHTML = Object.entries(VERS).map(([k, l]) => `<button class="chip" data-version="${k}">${l}</button>`).join(' ');

  const cinemaCount = {};
  sessions.forEach((s) => { cinemaCount[s.cinema] = (cinemaCount[s.cinema] || 0) + 1; });
  const cinemas = Object.keys(cinemaCount).sort((a, b) => a.localeCompare(b, 'es'));
  $('cinemas').innerHTML = cinemas.map((c) => `<button class="chip" data-cinema="${esc(c)}">${esc(c)}<span class="n">${cinemaCount[c]}</span></button>`).join('')
    + `<button class="chip" data-cinema-all="1">Todos</button>`;

  document.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    if (b.dataset.range) S.range = b.dataset.range;
    else if (b.dataset.version) S.version = b.dataset.version;
    else if (b.dataset.view) S.view = b.dataset.view;
    else if (b.dataset.cinema) { S.off.has(b.dataset.cinema) ? S.off.delete(b.dataset.cinema) : S.off.add(b.dataset.cinema); }
    else if (b.dataset.cinemaAll) { S.off = S.off.size ? new Set() : new Set(cinemas); }
    else if (b.id === 'special') S.special = !S.special;
    else if (b.id === 'academicos') S.academicos = !S.academicos;
    else if (b.dataset.ics) { downloadIcs(sessions.find((s) => s.key === b.dataset.ics)); return; }
    else if (b.dataset.film) { S.openFilms.has(b.dataset.film) ? S.openFilms.delete(b.dataset.film) : S.openFilms.add(b.dataset.film); render(); return; }
    else return;
    save(); render();
  });
  $('q').addEventListener('input', (e) => { S.q = e.target.value; render(); });
  $('maxprice').value = S.maxprice;
  $('maxprice').addEventListener('change', (e) => { S.maxprice = e.target.value; save(); render(); });

  // ---------- filtro ----------
  function visible() {
    const [from, to] = RANGES[S.range][1];
    const words = norm(S.q).split(/\s+/).filter(Boolean);
    const max = S.maxprice ? Number(S.maxprice) : null;
    return sessions.filter((s) =>
      s.day >= from && s.day <= to
      && !S.off.has(s.cinema)
      && (!S.special || s.special)
      && (S.academicos || !(s.tags || []).includes('solo académicos'))
      && (S.version === 'todas' || (S.version === 'vo' ? ['VOSE', 'VO'].includes(s.version) : s.version === 'DOBLADA'))
      && (max == null || (s.price_eur != null && s.price_eur <= max))
      && words.every((w) => s.hay.includes(w)));
  }

  // ---------- pintado ----------
  const tagHtml = (s) => {
    const t = [];
    if (s.version) t.push(`<span class="tag v-${s.version}">${s.version === 'ES' ? 'V.O. castellano' : s.version}</span>`);
    (s.tags || []).forEach((x) => t.push(`<span class="tag${SPECIAL.has(x) ? ' sp' : ''}">${esc(x)}</span>`));
    if (s.section && norm(s.section) !== norm(s.cycle)) t.push(`<span class="tag">${esc(s.section.toLowerCase())}</span>`);
    return t.length ? `<div class="tags">${t.join('')}</div>` : '';
  };
  const metaLine = (s) => [s.year, s.director, s.duration_min ? `${s.duration_min} min` : null].filter(Boolean).map(esc).join(' · ');

  function rowHtml(s) {
    const url = s.info_url || s.ticket_url;
    return `<article class="s${s.special ? ' special' : ''}">
      <div class="time">${s.start.slice(11, 16)}</div>
      <div class="thumb">${s.poster ? `<img src="${esc(s.poster)}" alt="" loading="lazy" referrerpolicy="no-referrer" onerror="this.remove()">` : ''}</div>
      <div>
        <div class="title">${url ? `<a href="${esc(url)}" target="_blank" rel="noopener">${esc(s.title)}</a>` : esc(s.title)}</div>
        ${metaLine(s) ? `<div class="sub">${metaLine(s)}</div>` : ''}
        <div class="where">${esc(s.cinema)}${s.room ? ` · ${esc(s.room)}` : ''}</div>
        ${s.cycle ? `<div class="cycle">${esc(s.cycle)}</div>` : ''}
        ${tagHtml(s)}
        ${s.note && !(s.tags || []).includes('solo académicos') ? `<div class="note">${esc(s.note)}</div>` : ''}
        ${s.stale ? '<div class="stale">Dato de la última lectura buena: la web del cine falló hoy</div>' : ''}
      </div>
      <div class="right">
        <div class="eur">${s.price_eur != null ? eur(s.price_eur) : '<span class="sub">precio en la compra</span>'}${s.price_note ? `<small>${esc(s.price_note)}</small>` : ''}</div>
        <div class="actions">
          <button class="btn ghost" data-ics="${s.key}" title="Añadir al calendario">＋ cal</button>
          ${s.ticket_url ? `<a class="btn" href="${esc(s.ticket_url)}" target="_blank" rel="noopener">Entradas</a>` : ''}
        </div>
      </div>
    </article>`;
  }

  function renderByDay(list) {
    const days = {};
    list.forEach((s) => (days[s.day] ||= []).push(s));
    return Object.keys(days).sort().map((d) =>
      `<section class="day"><h2>${dayLabel(d)}</h2>${days[d].map(rowHtml).join('')}</section>`).join('');
  }

  function renderByFilm(list) {
    const films = {};
    list.forEach((s) => {
      const k = norm(s.title).replace(/[^a-z0-9]+/g, ' ').trim();
      (films[k] ||= { title: s.title, year: s.year, director: s.director, items: [] }).items.push(s);
      films[k].year ||= s.year; films[k].director ||= s.director;
    });
    const arr = Object.values(films).sort((a, b) =>
      (b.items.some((s) => s.special) - a.items.some((s) => s.special)) || a.title.localeCompare(b.title, 'es'));
    const SLOTS = 4;
    return `<div class="grid">${arr.map((f) => {
      const tags = [...new Set(f.items.flatMap((s) => s.tags || []))].filter((x) => SPECIAL.has(x));
      const vers = [...new Set(f.items.map((s) => s.version).filter(Boolean))];
      const cyc = [...new Set(f.items.map((s) => s.cycle).filter(Boolean))];
      const cines = [...new Set(f.items.map((s) => s.cinema))];
      const poster = f.items.find((s) => s.poster)?.poster;
      const special = f.items.some((s) => s.special);
      const fk = norm(f.title).replace(/[^a-z0-9]+/g, '-');
      const open = S.openFilms.has(fk);
      const slots = (open ? f.items : f.items.slice(0, SLOTS)).map((s) => {
        const d = parse(s.start);
        return `<a class="slot${s.special ? ' sp' : ''}" href="${esc(s.ticket_url || s.info_url || '#')}" target="_blank" rel="noopener" title="${esc(s.cinema)}${s.room ? ' · ' + esc(s.room) : ''}${s.price_eur != null ? ' · ' + eur(s.price_eur) : ''}${s.cycle ? ' · ' + esc(s.cycle) : ''}">
          <span class="d">${DAYS[d.getDay()].slice(0, 3)} ${d.getDate()}</span> <b>${s.start.slice(11, 16)}</b>
          <span class="c">${esc(s.cinema.replace(/ \(.*\)$/, ''))}${s.version ? ' · ' + s.version : ''}${s.price_eur != null ? ' · ' + eur(s.price_eur) : ''}</span></a>`;
      }).join('');
      const more = f.items.length - SLOTS;
      return `<article class="card${special ? ' special' : ''}">
        <div class="poster">${poster ? `<img src="${esc(poster)}" alt="" loading="lazy" referrerpolicy="no-referrer" onerror="this.remove()">` : ''}
          <div class="ph">${esc(f.title)}</div>
          <div class="badges">${special ? '<span class="star">★</span>' : ''}${vers.map((v) => `<span class="tag v-${v}">${v === 'ES' ? 'V.O. cast.' : v}</span>`).join('')}</div>
        </div>
        <div class="body">
          <h3>${esc(f.title)}${f.year ? ` <span class="yr">${f.year}</span>` : ''}</h3>
          ${f.director ? `<div class="sub">${esc(f.director)}</div>` : ''}
          ${cyc.length ? `<div class="cycle">${cyc.map(esc).join(' · ')}</div>` : ''}
          ${tags.length ? `<div class="tags">${tags.map((x) => `<span class="tag sp">${esc(x)}</span>`).join('')}</div>` : ''}
          <div class="count">${f.items.length} ${f.items.length === 1 ? 'pase' : 'pases'} · ${cines.length} ${cines.length === 1 ? 'cine' : 'cines'}</div>
          <div class="slots">${slots}</div>
          ${more > 0 ? `<button class="more" data-film="${fk}">${open ? 'Ver menos' : `Ver ${more} más`}</button>` : ''}
        </div>
      </article>`;
    }).join('')}</div>`;
  }

  function render() {
    document.querySelectorAll('[data-range]').forEach((b) => b.classList.toggle('on', b.dataset.range === S.range));
    document.querySelectorAll('[data-version]').forEach((b) => b.classList.toggle('on', b.dataset.version === S.version));
    document.querySelectorAll('[data-view]').forEach((b) => b.classList.toggle('on', b.dataset.view === S.view));
    document.querySelectorAll('[data-cinema]').forEach((b) => b.classList.toggle('on', !S.off.has(b.dataset.cinema)));
    $('special').classList.toggle('on', S.special);
    $('academicos').classList.toggle('on', S.academicos);

    const list = visible();
    const nFilms = new Set(list.map((s) => norm(s.title))).size;
    const nSpecial = list.filter((s) => s.special).length;
    $('meta').textContent = `${list.length} pases · ${nFilms} películas · ${nSpecial} especiales — actualizado ${D.generated_at ? D.generated_at.replace('T', ' a las ') : '—'}`;
    $('list').innerHTML = list.length
      ? (S.view === 'dia' ? renderByDay(list) : renderByFilm(list))
      : '<p class="empty">Nada con estos filtros.</p>';
  }

  // ---------- calendario (.ics) ----------
  function downloadIcs(s) {
    if (!s) return;
    const st = parse(s.start);
    const en = new Date(st.getTime() + ((s.duration_min || 110) + 10) * 60e3);
    const f = (d) => `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}T${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}00`;
    const txt = (v) => String(v || '').replace(/[\\;,]/g, (c) => '\\' + c).replace(/\n/g, '\\n');
    const ics = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Cartelera personal//ES', 'BEGIN:VEVENT',
      `UID:${s.key}@cartelera`, `DTSTART;TZID=Europe/Madrid:${f(st)}`, `DTEND;TZID=Europe/Madrid:${f(en)}`,
      `SUMMARY:${txt(s.title)} — ${txt(s.cinema)}`, `LOCATION:${txt(s.cinema + (s.room ? ', ' + s.room : ''))}`,
      `DESCRIPTION:${txt([s.cycle, s.version, s.price_eur != null ? eur(s.price_eur) : null, s.ticket_url].filter(Boolean).join(' · '))}`,
      s.ticket_url ? `URL:${s.ticket_url}` : null, 'END:VEVENT', 'END:VCALENDAR'].filter(Boolean).join('\r\n');
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([ics], { type: 'text/calendar' }));
    a.download = `${norm(s.title).replace(/[^a-z0-9]+/g, '-')}-${s.start.slice(0, 10)}.ics`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }

  // ---------- estado de las fuentes ----------
  $('sources').innerHTML = `<strong>Fuentes</strong> (se leen de la web de cada cine)<ul>${(D.sources || []).map((s) =>
    `<li class="${s.ok ? '' : 'bad'}">${s.ok ? '●' : '○'} <a href="${esc(s.url)}" target="_blank" rel="noopener">${esc(s.name)}</a> — ${s.ok ? `${s.count} pases` : esc(s.error)}</li>`).join('')}</ul>`;

  render();
})();
