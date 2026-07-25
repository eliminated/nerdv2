# Phase 0 — Foundation You Can Run: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter Windows app that persists a subject across a restart, standing on a locked schema v1 with a tested migration harness and green CI.

**Architecture:** Three layers per [architecture.md §3.1](../../architecture.md#31-layering) — presentation depends on domain, data depends on domain, domain depends on nothing. Drift/SQLite is the only datastore. Riverpod provides DI. The schema is frozen at v1 at the end of this phase and every later change is additive-only.

**Tech Stack:** Flutter 3.41.4 · Dart 3.11.1 · Drift (via `drift_flutter`) · Riverpod · `uuid` v7 · GitHub Actions on `windows-latest`

## Global Constraints

Every task's requirements implicitly include this section.

- **Flutter 3.41.4 stable / Dart 3.11.1.** CI pins the same Flutter version. Do not run `flutter upgrade`.
- **Dart package name:** `nerdyapp`. All Flutter code lives in `app/`.
- **The domain layer imports neither Flutter nor Drift.** No `package:flutter/*`, no `package:drift/*` in `lib/domain/`.
- **All primary keys are UUIDv7 strings**, generated client-side via `const Uuid().v7()`. Never database-generated.
- **`schemaVersion` stays `1` for the whole of Phase 0.** If a task seems to need a schema change, stop and escalate — this is the phase that locks v1.
- **Migrations are additive-only** ([masterplan §5](../../masterplan.md#5-schema-strategy--the-migration-law)).
- **DateTime storage:** Drift's default (integer, UTC epoch seconds). Second precision is sufficient; durations are already integer seconds. `daily_summaries.local_date` is the exception — `TEXT` in `YYYY-MM-DD` form, frozen at write time per [masterplan §3](../../masterplan.md#3-locked-decisions) decision 11.
- **No server, no auth, no network calls.** Nothing in this phase may import an HTTP client.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `ci:`.
- **Branch:** all work on `feat/phase-0-foundation`, squash-merged to `main` at the end.

### Deliberate deviations from data-model.md

Record these; Task 9 annotates the source document.

| data-model.md says | Plan does | Why |
|---|---|---|
| `users.email` is `CITEXT UNIQUE NOT NULL`; `password_hash` is `NOT NULL` | Both nullable | No auth before v1.0 (decision 3). A local user has neither. `NULL → NOT NULL` is destructive, so this must be decided at v1, not later. |
| Indexes are partial: `WHERE deleted_at IS NULL` | Plain indexes | SQLite supports partial indexes, but drift's `@TableIndex` is used for schema-dump fidelity and the row counts here make the optimisation irrelevant. |
| `sessions.goal_id REFERENCES goals(id)` | Plain nullable text, no FK | The `goals` table does not exist until Phase 6. Adding it later is additive. |
| `topics.parent_topic_id REFERENCES topics(id)` | Plain nullable text, no FK | Avoids a self-referential FK in generated code. Tree integrity is enforced in Phase 4. |

**Correction applied after the Task 3 review (2026-07-25).** An earlier draft of this plan also
omitted `sessions.topic_id REFERENCES topics(id)` and the `UNIQUE` on `users.email`, without
listing either as a deviation. Both are now **included**, matching
[data-model.md](../../data-model.md) §3.1 and §3.4. The `topic_id` FK in particular could not
be deferred: SQLite cannot add a foreign key to an existing table, so leaving it out until
after the v1 freeze would have required exactly the destructive create-copy-drop-rename
rebuild that §5's additive-only law exists to prevent. Because every delete in this model is
soft (`deleted_at`), the FK can never block a deletion — it only rejects a session pointing at
a topic that never existed.

---

## File Structure

**Created in `app/`:**

| File | Responsibility |
|---|---|
| `pubspec.yaml`, `pubspec.lock` | Dependencies, pinned |
| `analysis_options.yaml` | Strict lints |
| `lib/main.dart` | Entry point: bootstrap then run |
| `lib/core/app.dart` | `MaterialApp`, theme, home route |
| `lib/core/providers.dart` | Riverpod root providers (database, repositories, current user id) |
| `lib/data/database/tables.dart` | The seven locked table definitions + `SyncColumns` mixin |
| `lib/data/database/database.dart` | `AppDatabase`, `schemaVersion = 1`, migration strategy |
| `lib/data/database/local_user.dart` | First-launch single-user bootstrap |
| `lib/data/database/database_backup.dart` | Copy the SQLite file to a chosen folder |
| `lib/data/repositories/subject_repository_impl.dart` | Drift-backed `SubjectRepository` |
| `lib/domain/entities/subject.dart` | Plain Dart `Subject` entity |
| `lib/domain/repositories/subject_repository.dart` | Repository interface |
| `lib/features/planner/presentation/subject_list_screen.dart` | Subject list + create form |
| `drift_schemas/drift_schema_v1.json` | **Committed.** The frozen v1 schema — the migration harness's reference |
| `test/generated_migrations/schema.dart` | **Committed.** Generated from the above |

**Created at repo root:** `.github/workflows/ci.yaml`, `.gitattributes`, `CONTRIBUTING.md`

**Modified at repo root:** `README.md`, `LICENSE`, `.gitignore`, `docs/focus-enforcement.md`, `docs/data-model.md`

---

## Task 1: Scaffold the Flutter Windows app

**Files:**
- Delete: `app/lib/main.dart` (0-byte placeholder — blocks `flutter create` from writing the template)
- Create: `app/pubspec.yaml`, `app/analysis_options.yaml`, `app/windows/**` (generated)
- Modify: `.gitignore`
- Create: `.gitattributes`

**Interfaces:**
- Produces: a buildable Flutter app at `app/` with package name `nerdyapp`.

- [ ] **Step 1: Remove the empty placeholder so the template can be generated**

```bash
rm app/lib/main.dart
```

- [ ] **Step 2: Generate the Windows-only scaffold**

Run from the repo root:

```bash
flutter create --platforms=windows --project-name nerdyapp app
```

Expected: creates `app/pubspec.yaml`, `app/windows/`, `app/lib/main.dart`, `app/test/widget_test.dart`.
`app/android/` stays empty — Android is post-finish and intentionally not generated.

- [ ] **Step 3: Add dependencies**

```bash
cd app && flutter pub add drift drift_flutter flutter_riverpod uuid file_selector
cd app && flutter pub add dev:drift_dev dev:build_runner
```

`path_provider` and `sqlite3` arrive transitively through `drift_flutter` and are not
imported directly, so they are deliberately not listed.

- [ ] **Step 4: Replace `analysis_options.yaml` with strict lints**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "test/generated_migrations/**"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - prefer_final_locals
    - prefer_single_quotes
    - require_trailing_commas
    - unawaited_futures
```

- [ ] **Step 5: Append to the root `.gitignore`**

```
# Flutter / Dart
app/build/
app/.dart_tool/
app/windows/flutter/ephemeral/
*.g.dart
```

- [ ] **Step 6: Create `.gitattributes` at the repo root**

Deterministic line endings — the schema-drift check in Task 4 compares generated JSON against the committed copy, and CRLF churn would make it fail spuriously.

```
* text=auto eol=lf
*.json text eol=lf
```

- [ ] **Step 7: Confirm `pubspec.lock` is tracked**

The Flutter *application* template does not ignore it, but confirm rather than assume —
an untracked lockfile means CI resolves different package versions than you do.

```bash
git check-ignore -v app/pubspec.lock || echo "TRACKED - good"
```
Expected: `TRACKED - good`. If a rule matches, remove it from `app/.gitignore`.

- [ ] **Step 8: Verify the app analyzes, tests, and builds**

```bash
cd app && flutter analyze
```
Expected: `No issues found!`

```bash
cd app && flutter test
```
Expected: the default `widget_test.dart` passes (1 test).

```bash
cd app && flutter build windows --debug
```
Expected: build succeeds, `Built build\windows\x64\runner\Debug\nerdyapp.exe`.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: scaffold Flutter Windows app with strict lints"
```

---

## Task 2: CI — analyze and test on every push

Sequenced second so every later task is validated automatically.

**Files:**
- Create: `.github/workflows/ci.yaml`

**Interfaces:**
- Produces: a `CI / analyze-and-test` check on every push and PR.

- [ ] **Step 1: Create the workflow**

```yaml
name: CI

on:
  push:
    branches: [main, 'feat/**', 'fix/**']
  pull_request:
    branches: [main]

jobs:
  analyze-and-test:
    runs-on: windows-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test
```

- [ ] **Step 2: Commit and push to trigger the run**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: analyze and test on windows-latest"
git push -u origin feat/phase-0-foundation
```

- [ ] **Step 3: Verify CI is green**

```bash
gh run list --limit 1
```
Expected: `completed  success  ci: analyze and test on windows-latest`.

If it fails, read the log and fix before continuing — a red pipeline at this point invalidates every later task's verification:

```bash
gh run view --log-failed
```

**This satisfies Phase 0 exit criterion 1.**

---

## Task 3: Drift schema v1 — the seven locked tables

**Files:**
- Create: `app/lib/data/database/tables.dart`
- Create: `app/lib/data/database/database.dart`
- Test: `app/test/data/database/schema_v1_test.dart`

**Interfaces:**
- Produces:
  - `class AppDatabase` with `AppDatabase(QueryExecutor e)` and `AppDatabase.defaults()`
  - Drift-generated tables `users`, `subjects`, `topics`, `sessions`, `session_surveys`, `interruptions`, `daily_summaries`
  - Generated row classes `UserRow`, `SubjectRow`, `TopicRow`, `SessionRow`, `SessionSurveyRow`, `InterruptionRow`, `DailySummaryRow`, and companions `UsersCompanion`, `SubjectsCompanion`, etc.

> **Why the `Row` suffix.** By default drift names the row class after the singular of the
> table class, so `Subjects` would generate `Subject` — colliding with the domain entity
> `Subject` from Task 6, and later with `Session` and `Topic`. `@DataClassName` renames only
> the generated Dart class; the SQL schema is unaffected, so the schema dump is identical
> either way. Settling it at v1 avoids a rename later, which the additive-only law forbids.

- [ ] **Step 1: Write the failing test**

`app/test/data/database/schema_v1_test.dart`:

```dart
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
          "SELECT name FROM sqlite_master "
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
        containsAll(<String>['id', 'created_at', 'updated_at', 'deleted_at', 'sync_state']),
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
        "INSERT INTO subjects (id, user_id, name, source, archived, "
        "created_at, updated_at, sync_state) "
        "VALUES ('s1', 'nope', 'Maths', 'self', 0, 0, 0, 'local')",
      ),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('a session rejects a dangling topic_id', () async {
    await db.customStatement(
      "INSERT INTO users (id, timezone, day_start_hour, created_at, "
      "updated_at, sync_state) VALUES ('u1', 'UTC', 4, 0, 0, 'local')",
    );
    await db.customStatement(
      "INSERT INTO subjects (id, user_id, name, source, archived, "
      "created_at, updated_at, sync_state) "
      "VALUES ('s1', 'u1', 'Maths', 'self', 0, 0, 0, 'local')",
    );

    await expectLater(
      db.customStatement(
        "INSERT INTO sessions (id, user_id, subject_id, topic_id, mode, "
        "paused_duration_s, started_at, created_at, updated_at, sync_state) "
        "VALUES ('x1', 'u1', 's1', 'nope', 'plain', 0, 0, 0, 0, 'local')",
      ),
      throwsConstraint('FOREIGN KEY'),
    );
  });

  test('duplicate non-null emails are rejected', () async {
    await db.customStatement(
      "INSERT INTO users (id, email, timezone, day_start_hour, created_at, "
      "updated_at, sync_state) "
      "VALUES ('u1', 'a@b.c', 'UTC', 4, 0, 0, 'local')",
    );

    await expectLater(
      db.customStatement(
        "INSERT INTO users (id, email, timezone, day_start_hour, created_at, "
        "updated_at, sync_state) "
        "VALUES ('u2', 'a@b.c', 'UTC', 4, 0, 0, 'local')",
      ),
      throwsConstraint('UNIQUE'),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/data/database/schema_v1_test.dart
```
Expected: FAIL — `Target of URI doesn't exist: 'package:nerdyapp/data/database/database.dart'`.

- [ ] **Step 3: Write the table definitions**

`app/lib/data/database/tables.dart`:

```dart
import 'package:drift/drift.dart';

/// The offline-first sync backbone. Every table carries these.
///
/// `syncState` is device-only and never transmitted. See
/// docs/data-model.md §2.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
}

/// A single local row until the post-finish server phase.
///
/// `email` and `passwordHash` are nullable, deviating from
/// docs/data-model.md §3.1: there is no auth before v1.0, and
/// NULL -> NOT NULL would be a destructive migration.
@DataClassName('UserRow')
class Users extends Table with SyncColumns {
  // UNIQUE per data-model.md §3.1. SQLite permits multiple NULLs in a unique
  // column, so the single credential-less local user is unaffected.
  TextColumn get email => text().nullable().unique()();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get timezone => text().withDefault(const Constant('UTC'))();
  IntColumn get dayStartHour => integer().withDefault(const Constant(4))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SubjectRow')
@TableIndex(name: 'idx_subjects_user', columns: {#userId})
class Subjects extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();

  /// 'school' | 'university' | 'course' | 'self'
  TextColumn get source => text().withDefault(const Constant('self'))();
  TextColumn get sourceName => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Self-referencing tree. `parentTopicId` carries no FK on purpose —
/// see the deviations table in the plan. Depth is capped at 3 in the UI
/// (Phase 4), not in the schema.
@DataClassName('TopicRow')
@TableIndex(name: 'idx_topics_subject', columns: {#subjectId})
@TableIndex(name: 'idx_topics_parent', columns: {#parentTopicId})
class Topics extends Table with SyncColumns {
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get parentTopicId => text().nullable()();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// 'not_started' | 'in_progress' | 'needs_review' | 'confident'
  TextColumn get status =>
      text().withDefault(const Constant('not_started'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The central fact table. Immutable once ended: only `endedAt`,
/// `actualDurationS` and `endReason` are ever written after creation.
/// `goalId` carries no FK — the goals table arrives in Phase 6.
@DataClassName('SessionRow')
@TableIndex(name: 'idx_sessions_user_started', columns: {#userId, #startedAt})
@TableIndex(name: 'idx_sessions_topic', columns: {#topicId})
class Sessions extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get topicId => text().nullable().references(Topics, #id)();
  TextColumn get goalId => text().nullable()();

  /// 'plain' | 'focused' | 'ultra_focus'
  TextColumn get mode => text()();
  IntColumn get plannedDurationS => integer().nullable()();

  /// Excludes paused time.
  IntColumn get actualDurationS => integer().nullable()();
  IntColumn get pausedDurationS => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 'completed' | 'user_ended' | 'abandoned' | 'crashed'
  TextColumn get endReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One-to-one with a session. Only `focusRating` is mandatory.
@DataClassName('SessionSurveyRow')
class SessionSurveys extends Table with SyncColumns {
  TextColumn get sessionId => text().references(Sessions, #id)();
  IntColumn get focusRating =>
      integer().check(focusRating.isBetweenValues(1, 5))();
  IntColumn get comprehensionRating => integer()
      .nullable()
      .check(comprehensionRating.isBetweenValues(1, 5))();
  IntColumn get difficultyRating =>
      integer().nullable().check(difficultyRating.isBetweenValues(1, 5))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sessionId},
      ];
}

/// Append-only event log. `detail` records kind, never identity —
/// see docs/focus-enforcement.md §7.
@DataClassName('InterruptionRow')
@TableIndex(name: 'idx_interruptions_session', columns: {#sessionId})
class Interruptions extends Table with SyncColumns {
  TextColumn get sessionId => text().references(Sessions, #id)();

  /// 'app_switch' | 'exit_attempt' | 'notification' | 'manual_pause'
  /// | 'idle_timeout' | 'device_locked' | 'self_reported'
  TextColumn get kind => text()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get durationS => integer().nullable()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  TextColumn get detail => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pure cache, fully recomputable. Never synced.
///
/// `localDate` is TEXT 'YYYY-MM-DD', frozen at write time
/// (masterplan decision 11).
@DataClassName('DailySummaryRow')
class DailySummaries extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get localDate => text()();
  IntColumn get totalSeconds => integer().withDefault(const Constant(0))();
  IntColumn get sessionCount => integer().withDefault(const Constant(0))();
  RealColumn get avgFocusRating => real().nullable()();
  BoolColumn get qualified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId, localDate},
      ];
}
```

- [ ] **Step 4: Write the database class**

`app/lib/data/database/database.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Schema v1 is frozen. Every later change is additive-only —
/// see docs/masterplan.md §5.
@DriftDatabase(
  tables: [
    Users,
    Subjects,
    Topics,
    Sessions,
    SessionSurveys,
    Interruptions,
    DailySummaries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(driftDatabase(name: 'nerdyapp'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
```

- [ ] **Step 5: Generate the drift code**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```
Expected: writes `lib/data/database/database.g.dart`, `Succeeded after ...`.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd app && flutter test test/data/database/schema_v1_test.dart
```
Expected: PASS, 7 tests.

- [ ] **Step 7: Commit**

```bash
git add app/lib/data/database app/test/data/database
git commit -m "feat: add drift schema v1 with the seven locked tables"
```

---

## Task 4: Migration harness — freeze v1 and detect drift

The countermeasure to what ended V1. Two guards: a `SchemaVerifier` test, and a CI check that the live schema still matches the committed dump.

**Files:**
- Create: `app/drift_schemas/drift_schema_v1.json` (generated, committed)
- Create: `app/test/generated_migrations/schema.dart` (generated, committed)
- Create: `app/test/data/database/migration_test.dart`
- Modify: `.github/workflows/ci.yaml`
- Modify: `app/analysis_options.yaml` (exclude generated migrations — already done in Task 1 Step 4; verify)

**Interfaces:**
- Consumes: `AppDatabase` from Task 3.
- Produces: `GeneratedHelper` (from the generated `schema.dart`), used by the verifier.

- [ ] **Step 1: Export the v1 schema**

```bash
cd app && dart run drift_dev schema dump lib/data/database/database.dart drift_schemas/
```
Expected: creates `app/drift_schemas/drift_schema_v1.json`.

- [ ] **Step 2: Generate the migration test helpers**

```bash
cd app && dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```
Expected: creates `app/test/generated_migrations/schema.dart` and `schema_v1.dart`.

- [ ] **Step 3: Write the migration test**

`app/test/data/database/migration_test.dart`:

```dart
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a database created at v1 validates against the committed schema',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });
}
```

- [ ] **Step 4: Run it to verify it passes**

```bash
cd app && flutter test test/data/database/migration_test.dart
```
Expected: PASS, 1 test.

- [ ] **Step 5: Prove the drift check actually catches a change**

This step verifies the *guard*, not the code. Temporarily add a column to `Subjects` in `tables.dart`:

```dart
  TextColumn get scratch => text().nullable()();
```

Then:

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
cd app && dart run drift_dev schema dump lib/data/database/database.dart drift_schemas/
cd app && git diff --stat drift_schemas/
```
Expected: `drift_schema_v1.json` shows as modified — the guard works.

Now revert:

```bash
cd app && git checkout drift_schemas/
```

Remove the `scratch` column from `tables.dart`, then:

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
cd app && git diff --exit-code drift_schemas/
```
Expected: exit code 0, no output.

- [ ] **Step 6: Add the drift check to CI**

Insert after the `Generate code` step in `.github/workflows/ci.yaml`:

```yaml
      - name: Verify schema dump is current
        run: |
          dart run drift_dev schema dump lib/data/database/database.dart drift_schemas/
          git diff --exit-code drift_schemas/
```

- [ ] **Step 7: Commit and confirm CI stays green**

```bash
git add app/drift_schemas app/test/generated_migrations app/test/data/database/migration_test.dart .github/workflows/ci.yaml
git commit -m "test: freeze schema v1 and detect schema drift in CI"
git push
gh run list --limit 1
```
Expected: `completed  success`.

**This satisfies Phase 0 exit criterion 3.**

---

## Task 5: Local user bootstrap

Decision 4: one local user row, created once with a UUIDv7, reused forever, so the post-finish server phase needs no migration.

**Files:**
- Create: `app/lib/data/database/local_user.dart`
- Test: `app/test/data/database/local_user_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 3.
- Produces: `class LocalUserBootstrap` with `LocalUserBootstrap(AppDatabase db)` and `Future<String> ensureLocalUser()` returning the user's UUID.

- [ ] **Step 1: Write the failing test**

`app/test/data/database/local_user_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';
import 'package:nerdyapp/data/database/local_user.dart';

void main() {
  late AppDatabase db;
  late LocalUserBootstrap bootstrap;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    bootstrap = LocalUserBootstrap(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates a user on first call', () async {
    final id = await bootstrap.ensureLocalUser();

    expect(id, isNotEmpty);
    final users = await db.select(db.users).get();
    expect(users, hasLength(1));
    expect(users.single.id, id);
  });

  test('returns the same id on every later call', () async {
    final first = await bootstrap.ensureLocalUser();
    final second = await bootstrap.ensureLocalUser();
    final third = await bootstrap.ensureLocalUser();

    expect(second, first);
    expect(third, first);
    expect(await db.select(db.users).get(), hasLength(1));
  });

  test('the local user has no credentials', () async {
    await bootstrap.ensureLocalUser();

    final user = (await db.select(db.users).get()).single;
    expect(user.email, isNull);
    expect(user.passwordHash, isNull);
  });

  test('day boundary defaults to 04:00 so past-midnight study counts '
      'toward the previous day', () async {
    await bootstrap.ensureLocalUser();

    final user = (await db.select(db.users).get()).single;
    expect(user.dayStartHour, 4);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && flutter test test/data/database/local_user_test.dart
```
Expected: FAIL — `Target of URI doesn't exist: '.../local_user.dart'`.

- [ ] **Step 3: Write the implementation**

`app/lib/data/database/local_user.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// Guarantees exactly one local user row.
///
/// There is no auth before v1.0 (masterplan decision 3), but every
/// `user_id` foreign key is populated from day one so that adding a
/// server later needs no migration (decision 4).
class LocalUserBootstrap {
  LocalUserBootstrap(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Returns the local user's id, creating the row if absent.
  Future<String> ensureLocalUser() async {
    final existing = await _db.select(_db.users).getSingleOrNull();
    if (existing != null) {
      return existing.id;
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v7();

    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return id;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd app && flutter test test/data/database/local_user_test.dart
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/database/local_user.dart app/test/data/database/local_user_test.dart
git commit -m "feat: bootstrap a single local user with a UUIDv7"
```

---

## Task 6: Subject domain and repository

The first vertical slice through all three layers. `Subject` is a plain Dart class with no Drift or Flutter imports.

**Files:**
- Create: `app/lib/domain/entities/subject.dart`
- Create: `app/lib/domain/repositories/subject_repository.dart`
- Create: `app/lib/data/repositories/subject_repository_impl.dart`
- Test: `app/test/data/repositories/subject_repository_test.dart`
- Test: `app/test/domain/entities/subject_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 3), `LocalUserBootstrap` (Task 5).
- Produces:
  - `class Subject` with fields `id`, `userId`, `name`, `color`, `source`, `sourceName`, `archived`, `createdAt`, `updatedAt`
  - `abstract interface class SubjectRepository` with `Future<List<Subject>> activeSubjects()`, `Future<Subject> create({required String userId, required String name, String? color, String source = 'self'})`, `Stream<List<Subject>> watchActiveSubjects()`
  - `class SubjectRepositoryImpl implements SubjectRepository` with `SubjectRepositoryImpl(AppDatabase db)`

- [ ] **Step 1: Write the failing domain test**

`app/test/domain/entities/subject_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/domain/entities/subject.dart';

void main() {
  test('two subjects with the same id are equal', () {
    final now = DateTime.utc(2026, 7, 25);
    final a = Subject(
      id: 'x',
      userId: 'u',
      name: 'Maths',
      createdAt: now,
      updatedAt: now,
    );
    final b = Subject(
      id: 'x',
      userId: 'u',
      name: 'Maths',
      createdAt: now,
      updatedAt: now,
    );

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('source defaults to self', () {
    final subject = Subject(
      id: 'x',
      userId: 'u',
      name: 'Maths',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(subject.source, 'self');
    expect(subject.archived, isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd app && flutter test test/domain/entities/subject_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the entity**

`app/lib/domain/entities/subject.dart`:

```dart
/// A subject the user studies.
///
/// Domain layer: no Flutter, no Drift imports (architecture.md §3.1).
class Subject {
  const Subject({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.source = 'self',
    this.sourceName,
    this.archived = false,
  });

  final String id;
  final String userId;
  final String name;
  final String? color;

  /// 'school' | 'university' | 'course' | 'self'
  final String source;
  final String? sourceName;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Write the repository interface**

`app/lib/domain/repositories/subject_repository.dart`:

```dart
import '../entities/subject.dart';

abstract interface class SubjectRepository {
  /// Live, archived, sorted by name.
  Future<List<Subject>> activeSubjects();

  Stream<List<Subject>> watchActiveSubjects();

  Future<Subject> create({
    required String userId,
    required String name,
    String? color,
    String source,
  });
}
```

- [ ] **Step 5: Write the failing repository test**

`app/test/data/repositories/subject_repository_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';
import 'package:nerdyapp/data/database/local_user.dart';
import 'package:nerdyapp/data/repositories/subject_repository_impl.dart';

void main() {
  late AppDatabase db;
  late SubjectRepositoryImpl repository;
  late String userId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = SubjectRepositoryImpl(db);
    userId = await LocalUserBootstrap(db).ensureLocalUser();
  });

  tearDown(() async {
    await db.close();
  });

  test('starts with no subjects', () async {
    expect(await repository.activeSubjects(), isEmpty);
  });

  test('creates a subject with a generated id', () async {
    final created = await repository.create(userId: userId, name: 'Physics');

    expect(created.id, isNotEmpty);
    expect(created.name, 'Physics');
    expect(created.userId, userId);
    expect(created.source, 'self');
    expect(created.archived, isFalse);
  });

  test('lists created subjects sorted by name', () async {
    await repository.create(userId: userId, name: 'Physics');
    await repository.create(userId: userId, name: 'Algebra');

    final names =
        (await repository.activeSubjects()).map((s) => s.name).toList();
    expect(names, <String>['Algebra', 'Physics']);
  });

  test('excludes soft-deleted subjects', () async {
    final subject = await repository.create(userId: userId, name: 'Physics');

    await db.customStatement(
      'UPDATE subjects SET deleted_at = ? WHERE id = ?',
      <Object>[DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000, subject.id],
    );

    expect(await repository.activeSubjects(), isEmpty);
  });

  test('excludes archived subjects', () async {
    final subject = await repository.create(userId: userId, name: 'Physics');

    await db.customStatement(
      'UPDATE subjects SET archived = 1 WHERE id = ?',
      <Object>[subject.id],
    );

    expect(await repository.activeSubjects(), isEmpty);
  });

  test('watchActiveSubjects emits on insert', () async {
    final emissions = <int>[];
    final subscription =
        repository.watchActiveSubjects().listen((s) => emissions.add(s.length));

    await repository.create(userId: userId, name: 'Physics');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await subscription.cancel();
    expect(emissions.last, 1);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

```bash
cd app && flutter test test/data/repositories/subject_repository_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 7: Write the implementation**

`app/lib/data/repositories/subject_repository_impl.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/subject.dart';
import '../../domain/repositories/subject_repository.dart';
import '../database/database.dart';

class SubjectRepositoryImpl implements SubjectRepository {
  SubjectRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  SimpleSelectStatement<$SubjectsTable, SubjectRow> _activeQuery() {
    return _db.select(_db.subjects)
      ..where((t) => t.deletedAt.isNull() & t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  }

  @override
  Future<List<Subject>> activeSubjects() async {
    final rows = await _activeQuery().get();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<Subject>> watchActiveSubjects() {
    return _activeQuery().watch().map(
          (rows) => rows.map(_toEntity).toList(),
        );
  }

  @override
  Future<Subject> create({
    required String userId,
    required String name,
    String? color,
    String source = 'self',
  }) async {
    final now = DateTime.now().toUtc();
    final subject = Subject(
      id: _uuid.v7(),
      userId: userId,
      name: name,
      color: color,
      source: source,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.subjects).insert(
          SubjectsCompanion.insert(
            id: subject.id,
            userId: subject.userId,
            name: subject.name,
            color: Value(subject.color),
            source: Value(subject.source),
            createdAt: subject.createdAt,
            updatedAt: subject.updatedAt,
          ),
        );

    return subject;
  }

  Subject _toEntity(SubjectRow row) => Subject(
        id: row.id,
        userId: row.userId,
        name: row.name,
        color: row.color,
        source: row.source,
        sourceName: row.sourceName,
        archived: row.archived,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}
```

`SubjectRow` is the drift-generated row class, named by the `@DataClassName('SubjectRow')`
annotation applied in Task 3. `SimpleSelectStatement` and `$SubjectsTable` are also
generated — if the analyzer cannot resolve them, codegen has not run.

- [ ] **Step 8: Run the tests to verify they pass**

```bash
cd app && flutter test test/data/repositories/subject_repository_test.dart test/domain/entities/subject_test.dart
```
Expected: PASS, 8 tests.

- [ ] **Step 9: Confirm the schema did not drift**

No schema change was intended in this task, so the dump must be byte-identical.

```bash
cd app && dart run drift_dev schema dump lib/data/database/database.dart drift_schemas/
cd app && git diff --exit-code drift_schemas/
```
Expected: exit 0, no output. A non-empty diff means an accidental schema change — stop and
escalate, because v1 is meant to be frozen.

- [ ] **Step 10: Commit**

```bash
git add app/lib/domain app/lib/data/repositories app/test/domain app/test/data/repositories
git commit -m "feat: add subject entity and drift-backed repository"
```

---

## Task 7: Riverpod wiring and the subject list screen

**Files:**
- Create: `app/lib/core/providers.dart`
- Create: `app/lib/core/app.dart`
- Create: `app/lib/features/planner/presentation/subject_list_screen.dart`
- Modify: `app/lib/main.dart`
- Delete: `app/test/widget_test.dart` (the scaffold's placeholder)
- Test: `app/test/features/planner/subject_list_screen_test.dart`

**Interfaces:**
- Consumes: `SubjectRepositoryImpl` (Task 6), `LocalUserBootstrap` (Task 5), `AppDatabase` (Task 3).
- Produces: `databaseProvider`, `subjectRepositoryProvider`, `localUserIdProvider`, `activeSubjectsProvider`; widget `SubjectListScreen`.

- [ ] **Step 1: Write the providers**

`app/lib/core/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database.dart';
import '../data/database/local_user.dart';
import '../data/repositories/subject_repository_impl.dart';
import '../domain/entities/subject.dart';
import '../domain/repositories/subject_repository.dart';

/// Overridden in tests with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepositoryImpl(ref.watch(databaseProvider));
});

final localUserIdProvider = FutureProvider<String>((ref) {
  return LocalUserBootstrap(ref.watch(databaseProvider)).ensureLocalUser();
});

final activeSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref.watch(subjectRepositoryProvider).watchActiveSubjects();
});
```

- [ ] **Step 2: Write the failing widget test**

`app/test/features/planner/subject_list_screen_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/core/providers.dart';
import 'package:nerdyapp/data/database/database.dart';
import 'package:nerdyapp/features/planner/presentation/subject_list_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget harness() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SubjectListScreen()),
    );
  }

  /// Pumps until the subject stream has delivered its first event.
  ///
  /// Do NOT use `pumpAndSettle()` for this: while the stream is still
  /// loading the screen shows a CircularProgressIndicator, which animates
  /// forever, so `pumpAndSettle` never settles and times out instead.
  Future<void> loadInitialFrame(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows an empty state when there are no subjects',
      (tester) async {
    await loadInitialFrame(tester);

    expect(find.text('No subjects yet'), findsOneWidget);
  });

  testWidgets('creates a subject and shows it in the list', (tester) async {
    await loadInitialFrame(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Physics');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('No subjects yet'), findsNothing);
  });

  testWidgets('rejects an empty subject name', (tester) async {
    await loadInitialFrame(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
cd app && flutter test test/features/planner/subject_list_screen_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 4: Write the screen**

`app/lib/features/planner/presentation/subject_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(activeSubjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load subjects: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No subjects yet'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(items[index].name),
              subtitle: Text(items[index].source),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New subject'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  setState(() => error = 'Name is required');
                  return;
                }
                final userId = await ref.read(localUserIdProvider.future);
                await ref
                    .read(subjectRepositoryProvider)
                    .create(userId: userId, name: name);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }
}
```

- [ ] **Step 5: Write the app shell and entry point**

`app/lib/core/app.dart`:

```dart
import 'package:flutter/material.dart';

import '../features/planner/presentation/subject_list_screen.dart';

class NerdyApp extends StatelessWidget {
  const NerdyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NerdyApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SubjectListScreen(),
    );
  }
}
```

`app/lib/main.dart` (replace entirely):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/providers.dart';

Future<void> main() async {
  // Required: AppDatabase.defaults() resolves its file through
  // path_provider, which needs the platform channels to be up.
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();

  // Guarantee the local user row exists before the first frame.
  await container.read(localUserIdProvider.future);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NerdyApp(),
    ),
  );
}
```

- [ ] **Step 6: Delete the scaffold's placeholder test**

```bash
rm app/test/widget_test.dart
```

- [ ] **Step 7: Run the whole suite**

```bash
cd app && flutter analyze
cd app && flutter test
```
Expected: `No issues found!`, then all tests pass — 23 total (7 schema, 1 migration, 4 local
user, 2 domain, 6 repository, 3 widget).

- [ ] **Step 8: Verify persistence by hand — Phase 0 exit criterion 2**

```bash
cd app && flutter run -d windows
```

1. The window opens showing **No subjects yet**.
2. Click **+**, type `Physics`, click **Create**. It appears in the list.
3. Close the window. Run `flutter run -d windows` again.
4. **`Physics` is still listed.** If it is not, the database is not being persisted to disk — stop and fix before continuing.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add subject list screen with riverpod wiring"
```

---

## Task 8: Database backup

Cheap insurance, given that unrecoverable database loss is what ended V1.

**Files:**
- Create: `app/lib/data/database/database_backup.dart`
- Test: `app/test/data/database/database_backup_test.dart`
- Modify: `app/lib/features/planner/presentation/subject_list_screen.dart` (add the action)

**Interfaces:**
- Consumes: `AppDatabase` (Task 3).
- Produces: `class DatabaseBackup` with `DatabaseBackup(AppDatabase db)` and `Future<File> backupTo(Directory target, {DateTime? now})`.

- [ ] **Step 1: Write the failing test**

`app/test/data/database/database_backup_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';
import 'package:nerdyapp/data/database/database_backup.dart';
import 'package:nerdyapp/data/database/local_user.dart';

void main() {
  late Directory workDir;
  late File dbFile;
  late AppDatabase db;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('nerdyapp_backup_test');
    dbFile = File('${workDir.path}${Platform.pathSeparator}source.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    await LocalUserBootstrap(db).ensureLocalUser();
  });

  tearDown(() async {
    await db.close();
    await workDir.delete(recursive: true);
  });

  test('writes a timestamped copy into the target directory', () async {
    final target = await Directory(
      '${workDir.path}${Platform.pathSeparator}out',
    ).create();

    final backup = await DatabaseBackup(db).backupTo(
      target,
      now: DateTime.utc(2026, 7, 25, 13, 45, 8),
    );

    expect(await backup.exists(), isTrue);
    expect(backup.path, endsWith('nerdyapp-backup-20260725-134508.sqlite'));
  });

  test('the backup is a valid sqlite database containing the user row',
      () async {
    final target = await Directory(
      '${workDir.path}${Platform.pathSeparator}out',
    ).create();

    final backup = await DatabaseBackup(db).backupTo(target);

    // Reopening through drift proves both that the file is valid SQLite
    // and that it carries the expected schema.
    final restored = AppDatabase(NativeDatabase(backup));
    addTearDown(restored.close);

    expect(await restored.select(restored.users).get(), hasLength(1));
  });

  test('throws if the target directory does not exist', () async {
    final missing = Directory(
      '${workDir.path}${Platform.pathSeparator}nope',
    );

    await expectLater(
      DatabaseBackup(db).backupTo(missing),
      throwsA(isA<FileSystemException>()),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd app && flutter test test/data/database/database_backup_test.dart
```
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

`app/lib/data/database/database_backup.dart`:

```dart
import 'dart:io';

import 'package:drift/drift.dart';

import 'database.dart';

/// Copies the SQLite file to a user-chosen folder.
///
/// Uses SQLite's own `VACUUM INTO`, which produces a consistent snapshot
/// even while the database is open — a plain file copy can capture a
/// torn write.
class DatabaseBackup {
  DatabaseBackup(this._db);

  final AppDatabase _db;

  Future<File> backupTo(Directory target, {DateTime? now}) async {
    if (!target.existsSync()) {
      throw FileSystemException('Target directory does not exist', target.path);
    }

    final stamp = _stamp(now ?? DateTime.now().toUtc());
    final destination = File(
      '${target.path}${Platform.pathSeparator}nerdyapp-backup-$stamp.sqlite',
    );

    if (destination.existsSync()) {
      destination.deleteSync();
    }

    // VACUUM INTO takes a literal path; escape single quotes.
    final escaped = destination.path.replaceAll("'", "''");
    await _db.customStatement("VACUUM INTO '$escaped'");

    return destination;
  }

  String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}${two(at.month)}${two(at.day)}'
        '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd app && flutter test test/data/database/database_backup_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Add the backup action to the app bar**

In `subject_list_screen.dart`, add these imports:

```dart
import 'package:file_selector/file_selector.dart';

import '../../../data/database/database_backup.dart';
```

Replace the `AppBar` line with:

```dart
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Back up database',
            onPressed: () => _backup(context, ref),
          ),
        ],
      ),
```

And add this method to the class:

```dart
  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final path = await getDirectoryPath();
    if (path == null) {
      return;
    }

    final file = await DatabaseBackup(ref.read(databaseProvider))
        .backupTo(Directory(path));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backed up to ${file.path}')),
      );
    }
  }
```

Add `import 'dart:io';` at the top of the file.

- [ ] **Step 6: Verify the suite and the manual path — Phase 0 exit criterion 4**

```bash
cd app && flutter analyze
cd app && flutter test
```
Expected: clean, all tests pass — 26 total (23 from Task 7, plus 3 backup tests).

On Windows the `tearDown` deletes the temp directory immediately after closing the database.
If a test fails with a file-lock error, the close did not complete — check that every
`AppDatabase` opened in the test has a matching `addTearDown(db.close)`.

```bash
cd app && flutter run -d windows
```

Click the save icon, choose a folder, confirm the snackbar names a file, and confirm the
file exists and is non-zero on disk.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add database backup via VACUUM INTO"
```

---

## Task 9: Documentation hygiene

Brings the repository's own documents in line with the masterplan.

**Files:**
- Modify: `README.md` (roadmap, iteration history, licence, prerequisites, structure, changelog row)
- Modify: `LICENSE` (currently empty)
- Modify: `docs/focus-enforcement.md` (§4 Windows notification claim)
- Modify: `docs/data-model.md` (§3.1 nullable credentials note)
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Write the MIT licence**

Replace the empty `LICENSE` with exactly this:

```
MIT License

Copyright (c) 2026 Isaac

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Correct the Windows notification claim**

In `docs/focus-enforcement.md` §4, change the "Suppress notifications" row's Windows cell
from:

```
| Suppress notifications | ✅ `NotificationManager` DND (`ACCESS_NOTIFICATION_POLICY`) | ✅ Focus Assist / `SHQueryUserNotificationState` | Both need user grant |
```

to:

```
| Suppress notifications | ✅ `NotificationManager` DND (`ACCESS_NOTIFICATION_POLICY`) | ⚠️ `SHQueryUserNotificationState` **reads** notification state; no documented public API **enables** Focus Assist | Android needs user grant; Windows may require a manual toggle — see masterplan R1 |
```

- [ ] **Step 3: Annotate the credentials deviation**

In `docs/data-model.md` §3.1, immediately after the `users` SQL block, add:

```markdown
> **Local-only deviation (V2, pre-1.0).** The on-device SQLite schema makes `email` and
> `password_hash` **nullable**. There is no authentication before v1.0
> ([masterplan](./masterplan.md#3-locked-decisions) decision 3), so the single local user
> row has neither. `NULL → NOT NULL` is a destructive change under the additive-only
> migration law, so this is settled at schema v1 rather than deferred. The columns above
> describe the eventual server schema.
```

- [ ] **Step 4: Rewrite the README roadmap**

Replace the entire `## Roadmap` section — from the `## Roadmap` heading down to (but not
including) `## Development workflow` — with exactly this:

```markdown
## Roadmap

> Sequencing, exit criteria, and locked decisions live in
> [docs/masterplan.md](docs/masterplan.md), which is authoritative. This section is a summary.

Build iteration V2 targets a **Windows desktop app** first. Android, the server, sync, and
authentication are deliberately post-1.0 — see the masterplan for why.

| Phase | Delivers |
|---|---|
| 0 — Foundation | Scaffold, schema v1 with a tested migration harness, CI, subject list |
| 1 — Core loop | Session timer with crash recovery; sessions recorded correctly |
| 2 — The signal | Post-session survey and interruption log |
| 3 — Focused mode | Fullscreen sessions; leaving detected, logged, and surfaced |
| 4 — Topics & mastery | Topic tree, session tagging, computed mastery |
| 5 — Consistency & insight | Quality-weighted streak, calendar heatmap, analytics |
| 6 — Goals & routines | Recurring study schedule with derived adherence |
| 7 — Companion tools | Notepad, distraction parking list, ambient sound |
| 8 — Export & durability | CSV/JSON export, backup and restore, delete-all |
| 9 — Finish | Windows installer, polish, `v1.0.0` |

**Post-1.0, each independently optional:** Android port (screen pinning, DND) · server and
sync · hard Ultra-Focus enforcement, gated on what the interruption log shows · spaced
repetition · external course tracking · accountability features.
```

Also in `README.md`:
- Fill the V1 row of the iteration-history table from [masterplan §1](docs/masterplan.md#1-v1-post-mortem).
- Replace the `## License` `TODO` with: `Released under the [MIT License](LICENSE).`
- Correct the clone URL in **Installation** from `https://github.com/<user>/nerdyapp.git` to `https://github.com/eliminated/nerdv2.git`, and the directory from `nerdyapp` to `nerdv2`.
- Update **Prerequisites** to `Flutter 3.41.4 (Dart 3.11.1)`, `Visual Studio 2022 with the Desktop development with C++ workload`, and remove the Python and PostgreSQL lines — there is no server before v1.0.
- Remove `server/` from the project-structure diagram, and add `docs/masterplan.md`.
- Set **Maintainer** to `Isaac`.
- Add `docs/masterplan.md` to the related-documents list.

- [ ] **Step 5: Add the required README changelog row**

The `<!-- REQUIRED -->` marker in `README.md` mandates this. Append:

```markdown
| 1.1 | - Roadmap replaced with masterplan phases; V1 post-mortem filled; MIT licence; prerequisites corrected for Windows-first Flutter build; server removed from structure | Claude\nIsaac |
```

- [ ] **Step 6: Write `CONTRIBUTING.md`**

Create it at the repo root with exactly this content (the outer fence is four backticks
because the file itself contains fenced blocks — do not copy the outer fence):

````markdown
# Contributing

Please open an issue before starting significant work so the approach can be agreed first.

[docs/masterplan.md](docs/masterplan.md) is authoritative for sequencing and for decisions
already locked. If a change contradicts it, change the masterplan in the same pull request.

## Getting set up

Requires **Flutter 3.41.4** (Dart 3.11.1) and **Visual Studio 2022** with the *Desktop
development with C++* workload.

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The codegen step is **not optional**. Generated `*.g.dart` files are git-ignored, so a fresh
clone will not analyze until you have run it.

```bash
flutter run -d windows
```

## The migration law

Pre-1.0, **migrations are additive-only**: new tables, and new nullable columns or columns
with a constant default. No renames, no drops, no type changes, no `NOT NULL` without a
default.

Schema churn is what ended build iteration V1, so this is enforced mechanically:

- `app/drift_schemas/drift_schema_v*.json` is the committed schema history. CI re-runs
  `drift_dev schema dump` and fails if the result differs from what is committed.
- Changing `schemaVersion` requires dumping the new schema, regenerating
  `test/generated_migrations/`, and adding a `SchemaVerifier` test that migrates from the
  previous version and validates.
- Anything destructive additionally requires a test that runs the migration against a
  fixture database seeded at the previous version and asserts no row loss.

## Code layout

Three layers, feature-first. The **domain layer imports neither Flutter nor Drift** — that
rule is what keeps the correctness-critical logic testable without a device, which matters
here because focus-enforcement behaviour cannot be tested automatically at all.

Correctness-critical code is written test-first: the session timer, streak and summary
computation, migrations, and routine adherence.

## Before opening a pull request

```bash
cd app
flutter analyze   # must report no issues
flutter test      # must be green
```

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`,
  `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `ci:`.
- **Branches:** GitHub Flow. Short-lived branches off `main` (`feat/session-timer`,
  `fix/streak-reset`), squash-merged.
- **Changelog:** update `CHANGELOG.md` under `## [Unreleased]`, following
  [Keep a Changelog](https://keepachangelog.com/).
- **Editing `README.md`** requires adding a row to its README changelog table.
````

- [ ] **Step 7: Verify no document still contradicts the masterplan**

```bash
grep -rn "Authentication" README.md
grep -rn "PostgreSQL\|Python 3.11" README.md
```
Expected: no roadmap hit for `Authentication`; no prerequisite hits for the server stack.
Mentions inside the tech-stack table are fine — that table describes the eventual system.

- [ ] **Step 8: Commit**

```bash
git add README.md LICENSE CONTRIBUTING.md docs/focus-enforcement.md docs/data-model.md
git commit -m "docs: align README and design docs with the masterplan"
```

---

## Task 10: Close the phase

- [ ] **Step 1: Confirm all four exit criteria, with output seen**

```bash
cd app && flutter analyze
cd app && flutter test
```
Expected: `No issues found!` and all tests passing.

```bash
git push
gh run list --limit 1
```
Expected: `completed  success`. **Criterion 1 met.**

Criterion 2 — verified by hand in Task 7 Step 8 (subject survives a restart).
Criterion 3 — the migration test and the CI drift check, Task 4. **Verified.**
Criterion 4 — verified by hand in Task 8 Step 6 (backup opens as valid SQLite).

- [ ] **Step 2: Record the phase in the changelog**

Create the `CHANGELOG.md` entry per [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [Unreleased]

### Added
- Flutter Windows scaffold with strict lints and CI on `windows-latest`.
- Drift schema v1: users, subjects, topics, sessions, session_surveys,
  interruptions, daily_summaries. Frozen; later changes are additive-only.
- Migration harness: committed schema dump, `SchemaVerifier` test, and a CI
  check that fails on undeclared schema drift.
- Single local user bootstrap with a client-generated UUIDv7.
- Subject list with create, backed by Drift and wired through Riverpod.
- Database backup via `VACUUM INTO`.
```

```bash
git add CHANGELOG.md
git commit -m "docs: record phase 0 in the changelog"
```

- [ ] **Step 3: Open the PR**

```bash
git push
gh pr create --title "Phase 0: foundation you can run" --body "Implements docs/superpowers/plans/2026-07-25-phase-0-foundation.md.

Schema v1 is frozen at the end of this phase. All four exit criteria verified:
- flutter analyze / flutter test green in CI
- a subject survives an app restart (manual, Windows)
- schema-verification test plus a CI drift check
- backup produces a valid SQLite file

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 4: Squash-merge once CI is green**

```bash
gh pr checks
gh pr merge --squash --delete-branch
```

---

## Notes for the implementer

**If `flutter create` refuses to write into `app/`** because the directory is non-empty:
that is expected and fine — it fills in missing files. Only `lib/main.dart` needed removing
first, because a 0-byte file already there would be left alone and you would end up with no
entry point.

**Row class names are set explicitly** via `@DataClassName` in Task 3 — `UserRow`,
`SubjectRow`, and so on. Without it drift would generate `Subject`, colliding with the domain
entity of the same name. If the analyzer reports an ambiguous `Subject`, check that those
annotations survived and that codegen has run.

**If the CI schema-drift check fails spuriously** with only line-ending differences, confirm
`.gitattributes` from Task 1 Step 7 is committed and run
`git add --renormalize app/drift_schemas/`.

**Do not change `schemaVersion`.** Phase 0's entire purpose is to leave v1 frozen and
guarded. If a genuine schema problem surfaces, fix it *within* this phase before merging —
after the merge, every change is additive-only forever.
