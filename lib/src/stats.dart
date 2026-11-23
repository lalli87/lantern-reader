import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app.dart';
import 'db.dart';

/// Reading and listening time, kept per day and book in the `activity` table.

String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Activity {
  /// Adds time to today's totals for [bookId].
  static Future<void> add(int bookId, {int readMs = 0, int listenMs = 0}) async {
    if (readMs <= 0 && listenMs <= 0) return;
    final day = dayKey(DateTime.now());
    await Db.db.rawInsert(
      'INSERT INTO activity(day, book_id, read_ms, listen_ms) VALUES(?, ?, ?, ?) '
      'ON CONFLICT(day, book_id) DO UPDATE SET read_ms = read_ms + excluded.read_ms, listen_ms = listen_ms + excluded.listen_ms',
      [day, bookId, readMs, listenMs],
    );
  }

  /// (read ms, listen ms) per day for the last [n] days, oldest first.
  static Future<List<(DateTime, int, int)>> days(int n, {DateTime? today}) async {
    final end = today ?? DateTime.now();
    final start = DateTime(end.year, end.month, end.day).subtract(Duration(days: n - 1));
    final rows = await Db.db.rawQuery(
        'SELECT day, SUM(read_ms) r, SUM(listen_ms) l FROM activity WHERE day >= ? GROUP BY day', [dayKey(start)]);
    final by = {for (final r in rows) r['day'] as String: ((r['r'] as num?)?.toInt() ?? 0, (r['l'] as num?)?.toInt() ?? 0)};
    return [
      for (var i = 0; i < n; i++)
        () {
          final d = DateTime(start.year, start.month, start.day + i);
          final v = by[dayKey(d)] ?? (0, 0);
          return (d, v.$1, v.$2);
        }(),
    ];
  }

  /// Total (read ms, listen ms) since [from] (inclusive day).
  static Future<(int, int)> since(DateTime from) async {
    final r = await Db.db.rawQuery(
        'SELECT SUM(read_ms) r, SUM(listen_ms) l FROM activity WHERE day >= ?', [dayKey(from)]);
    return ((r.first['r'] as num?)?.toInt() ?? 0, (r.first['l'] as num?)?.toInt() ?? 0);
  }

  /// Days in a row, up to today, with at least a minute of reading or listening. A day not yet started
  /// today doesn't break the streak.
  static Future<int> streak({DateTime? today}) async {
    final now = today ?? DateTime.now();
    final rows = await Db.db.rawQuery(
        'SELECT day FROM activity GROUP BY day HAVING SUM(read_ms) + SUM(listen_ms) >= 60000 ORDER BY day DESC LIMIT 400');
    final days = {for (final r in rows) r['day'] as String};
    var d = DateTime(now.year, now.month, now.day);
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  /// Books with the most time since [from]: (book id, title, read ms, listen ms).
  static Future<List<(int, String, int, int)>> topBooks(DateTime from, {int limit = 5}) async {
    final rows = await Db.db.rawQuery(
        'SELECT a.book_id id, b.title t, SUM(a.read_ms) r, SUM(a.listen_ms) l FROM activity a LEFT JOIN books b ON b.id = a.book_id '
        'WHERE a.day >= ? GROUP BY a.book_id ORDER BY SUM(a.read_ms) + SUM(a.listen_ms) DESC LIMIT ?',
        [dayKey(from), limit]);
    return [
      for (final r in rows)
        (r['id'] as int, (r['t'] as String?) ?? 'A removed book', (r['r'] as num?)?.toInt() ?? 0, (r['l'] as num?)?.toInt() ?? 0),
    ];
  }

  /// Books finished since [from]: (book id, title, finished at).
  static Future<List<(int, String, int)>> finished(DateTime from) async {
    final rows = await Db.db.rawQuery(
        'SELECT f.book_id id, b.title t, f.at at FROM finished f LEFT JOIN books b ON b.id = f.book_id WHERE f.at >= ? ORDER BY f.at DESC',
        [from.millisecondsSinceEpoch]);
    return [for (final r in rows) (r['id'] as int, (r['t'] as String?) ?? 'A removed book', r['at'] as int)];
  }
}

/// Counts reading time while a book is open, the app is in front and the reader has touched the screen
/// in the last few minutes (so a book left open on the table doesn't count). Listening is counted by the
/// narrator instead.
class ReadingTimer with WidgetsBindingObserver {
  ReadingTimer(this.bookId, {this.isListening});
  final int? Function() bookId;
  final bool Function()? isListening;
  static const idle = Duration(minutes: 3);
  Timer? _t;
  DateTime _active = DateTime.now(), _last = DateTime.now();
  bool _front = true;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _last = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  /// Call on any touch or scroll.
  void poke() => _active = DateTime.now();

  void _tick() {
    final now = DateTime.now();
    final elapsed = now.difference(_last);
    _last = now;
    final id = bookId();
    if (id == null || !_front || (isListening?.call() ?? false)) return;
    if (now.difference(_active) > idle) return;
    Activity.add(id, readMs: math.min(elapsed.inMilliseconds, 60000));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final front = state == AppLifecycleState.resumed;
    if (front && !_front) _last = DateTime.now();
    if (!front && _front) _tick();
    _front = front;
  }

  void stop() {
    _tick();
    _t?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

String fmtDuration(int ms) {
  final m = (ms / 60000).round();
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

// ---- screen ----

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<(DateTime, int, int)> _days = [];
  (int, int) _today = (0, 0), _week = (0, 0), _month = (0, 0), _year = (0, 0);
  int _streak = 0;
  List<(int, String, int, int)> _top = [];
  List<(int, String, int)> _finished = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(Duration(days: today.weekday - 1));
    final month = DateTime(now.year, now.month, 1), year = DateTime(now.year, 1, 1);
    final days = await Activity.days(14);
    final t = await Activity.since(today), w = await Activity.since(week), m = await Activity.since(month), y = await Activity.since(year);
    final s = await Activity.streak();
    final top = await Activity.topBooks(month);
    final fin = await Activity.finished(year);
    if (!mounted) return;
    setState(() {
      _days = days;
      _today = t;
      _week = w;
      _month = m;
      _year = y;
      _streak = s;
      _top = top;
      _finished = fin;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    Widget card(String label, (int, int) v) => Expanded(
          child: Card(
            margin: const EdgeInsets.all(4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(fmtDuration(v.$1 + v.$2), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${fmtDuration(v.$1)} read · ${fmtDuration(v.$2)} heard', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
        );
    final maxMs = _days.fold<int>(0, (a, d) => math.max(a, d.$2 + d.$3));
    final read = cs.primary, listen = cs.tertiary;
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Reading stats')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
                Row(children: [card('Today', _today), card('This week', _week)]),
                Row(children: [card('This month', _month), card('This year', _year)]),
                Card(
                  margin: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: Icon(Icons.local_fire_department_outlined, color: cs.primary),
                    title: Text(_streak == 0 ? 'No streak yet' : '$_streak day${_streak == 1 ? '' : 's'} in a row'),
                    subtitle: const Text('Days with at least a minute of reading or listening'),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Expanded(child: Text('Last 14 days', style: tt.titleMedium)),
                    _Legend(read, 'Reading'),
                    const SizedBox(width: 12),
                    _Legend(listen, 'Listening'),
                  ]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final d in _days)
                      Expanded(
                        child: Tooltip(
                          message: '${MaterialLocalizations.of(context).formatShortMonthDay(d.$1)}: ${fmtDuration(d.$2)} read, ${fmtDuration(d.$3)} heard',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              if (maxMs > 0) ...[
                                Container(height: 120 * d.$3 / maxMs, decoration: BoxDecoration(color: listen, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))),
                                Container(height: 120 * d.$2 / maxMs, color: read),
                              ],
                              const SizedBox(height: 4),
                              Text(MaterialLocalizations.of(context).narrowWeekdays[d.$1.weekday % 7],
                                  style: tt.labelSmall?.copyWith(
                                      color: dayKey(d.$1) == dayKey(DateTime.now()) ? cs.primary : cs.onSurfaceVariant)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
                if (maxMs == 0)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Time spent reading and listening shows up here.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                const SizedBox(height: 16),
                if (_top.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.all(4), child: Text('Most time this month', style: tt.titleMedium)),
                  for (final b in _top)
                    ListTile(
                      dense: true,
                      title: Text(b.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${fmtDuration(b.$3)} read · ${fmtDuration(b.$4)} heard'),
                      trailing: Text(fmtDuration(b.$3 + b.$4), style: tt.labelLarge),
                    ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                      _finished.isEmpty
                          ? 'No books finished yet this year'
                          : '${_finished.length} book${_finished.length == 1 ? '' : 's'} finished this year',
                      style: tt.titleMedium),
                ),
                for (final f in _finished)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.done_all, color: cs.primary),
                    title: Text(f.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(MaterialLocalizations.of(context).formatShortMonthDay(DateTime.fromMillisecondsSinceEpoch(f.$3))),
                  ),
              ]),
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}

