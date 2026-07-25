import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> tableNames() async {
    final rows = await db
        .customSelect(
          'SELECT name FROM sqlite_master '
          "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  test('schema v1 creates the seven locked tables', () async {
    expect(
      await tableNames(),
      containsAll(<String>[
        'users',
        'subjects',
        'topics',
        'sessions',
        'session_surveys',
        'interruptions',
        'daily_summaries',
      ]),
    );
  });

  test('schemaVersion is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('every table carries the sync columns', () async {
    for (final table in <String>[
      'users',
      'subjects',
      'topics',
      'sessions',
      'session_surveys',
      'interruptions',
      'daily_summaries',
    ]) {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      final columns = rows.map((row) => row.read<String>('name')).toSet();
      expect(
        columns,
        containsAll(<String>[
          'id',
          'created_at',
          'updated_at',
          'deleted_at',
          'sync_state',
        ]),
        reason: '$table is missing sync columns',
      );
    }
  });

  test('foreign keys are enforced', () async {
    final rows = await db.customSelect('PRAGMA foreign_keys').get();
    expect(rows.single.read<int>('foreign_keys'), 1);
  });

  test('a subject rejects a dangling user_id', () async {
    await expectLater(
      db.customStatement(
        'INSERT INTO subjects (id, user_id, name, source, archived, '
        'created_at, updated_at, sync_state) '
        "VALUES ('s1', 'nope', 'Maths', 'self', 0, 0, 0, 'local')",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
