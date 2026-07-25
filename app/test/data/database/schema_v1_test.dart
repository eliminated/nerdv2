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

  /// Matches a specific SQLite constraint failure. A bare `isA<Exception>()`
  /// would also pass for a typo in a column name, so the test would keep
  /// passing while silently testing nothing.
  Matcher throwsConstraint(String constraint) => throwsA(
    isA<Exception>().having(
      (Exception e) => e.toString(),
      'message',
      contains(constraint),
    ),
  );

  test('a subject rejects a dangling user_id', () async {
    await expectLater(
      db.customStatement(
        'INSERT INTO subjects (id, user_id, name, source, archived, '
        'created_at, updated_at, sync_state) '
        "VALUES ('s1', 'nope', 'Maths', 'self', 0, 0, 0, 'local')",
      ),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('a session rejects a dangling topic_id', () async {
    await db.customStatement(
      'INSERT INTO users (id, timezone, day_start_hour, created_at, '
      "updated_at, sync_state) VALUES ('u1', 'UTC', 4, 0, 0, 'local')",
    );
    await db.customStatement(
      'INSERT INTO subjects (id, user_id, name, source, archived, '
      'created_at, updated_at, sync_state) '
      "VALUES ('s1', 'u1', 'Maths', 'self', 0, 0, 0, 'local')",
    );

    await expectLater(
      db.customStatement(
        'INSERT INTO sessions (id, user_id, subject_id, topic_id, mode, '
        'paused_duration_s, started_at, created_at, updated_at, sync_state) '
        "VALUES ('x1', 'u1', 's1', 'nope', 'plain', 0, 0, 0, 0, 'local')",
      ),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('duplicate non-null emails are rejected', () async {
    await db.customStatement(
      'INSERT INTO users (id, email, timezone, day_start_hour, created_at, '
      'updated_at, sync_state) '
      "VALUES ('u1', 'a@b.c', 'UTC', 4, 0, 0, 'local')",
    );

    await expectLater(
      db.customStatement(
        'INSERT INTO users (id, email, timezone, day_start_hour, created_at, '
        'updated_at, sync_state) '
        "VALUES ('u2', 'a@b.c', 'UTC', 4, 0, 0, 'local')",
      ),
      throwsConstraint('UNIQUE'),
    );
  });
}
