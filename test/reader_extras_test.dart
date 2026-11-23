import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern_reader/src/db.dart';
import 'package:lantern_reader/src/reader_extras.dart';
import 'package:lantern_reader/src/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await Db.open(inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  });
  tearDownAll(Db.close);

  test('night theme by schedule (also across midnight) and by the phone\'s dark mode', () async {
    final s = Settings();
    await s.load();
    expect(nightWanted(s, DateTime(2026, 1, 1, 23), Brightness.light), isNull, reason: 'off by default');
    s.set('autoNight', 'schedule'); // 21:00 – 07:00
    expect(nightWanted(s, DateTime(2026, 1, 1, 22, 30), Brightness.light), isTrue);
    expect(nightWanted(s, DateTime(2026, 1, 1, 3), Brightness.light), isTrue);
    expect(nightWanted(s, DateTime(2026, 1, 1, 7), Brightness.light), isFalse);
    expect(nightWanted(s, DateTime(2026, 1, 1, 12), Brightness.light), isFalse);
    s.set('nightFrom', 13 * 60);
    s.set('nightTo', 15 * 60);
    expect(nightWanted(s, DateTime(2026, 1, 1, 14), Brightness.light), isTrue);
    expect(nightWanted(s, DateTime(2026, 1, 1, 16), Brightness.light), isFalse);
    s.set('autoNight', 'system');
    expect(nightWanted(s, DateTime(2026, 1, 1, 12), Brightness.dark), isTrue);
    expect(fmtClockMinutes(7 * 60 + 5), '07:05');
  });

  test('time left in a chapter', () {
    expect(timeLeftLabel(0), 'End of chapter');
    expect(timeLeftLabel(1), '1 min left in chapter');
    expect(timeLeftLabel(6000), '6 min left in chapter');
    expect(timeLeftLabel(90000), '1.5 h left in chapter');
  });
}
