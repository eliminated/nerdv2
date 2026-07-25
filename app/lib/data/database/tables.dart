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
  TextColumn get status => text().withDefault(const Constant('not_started'))();

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
  // The self-reference inside check() is drift's documented way to name the
  // column being constrained. drift_dev reads these getters at build time and
  // the generated table shadows them with real columns, so the apparent
  // recursion is never evaluated at runtime.
  IntColumn get focusRating =>
      // ignore: recursive_getters
      integer().check(focusRating.isBetweenValues(1, 5))();
  IntColumn get comprehensionRating =>
      // ignore: recursive_getters
      integer().nullable().check(comprehensionRating.isBetweenValues(1, 5))();
  IntColumn get difficultyRating =>
      // ignore: recursive_getters
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
