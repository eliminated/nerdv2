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
