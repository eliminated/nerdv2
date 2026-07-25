import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  // `migrateAndValidate` builds its reference schema by instantiating
  // `GeneratedHelper` at the target version — i.e. from the committed
  // drift_schemas/drift_schema_v1.json — and compares it against the schema it
  // reads out of `sqlite_master` for the database it is handed.
  //
  // The database therefore MUST be empty. An empty database opens with
  // user_version 0, so drift runs `onCreate` -> `createAll()`, building the
  // tables from the live generated code. That is the comparison we want:
  // tables.dart against the committed snapshot.
  //
  // Do not seed it from `verifier.startAt(1)`. That would pre-create the tables
  // from the snapshot, drift would run no migration (stored version already
  // equals the target), and both sides of the comparison would come from the
  // snapshot — the test would pass no matter how far tables.dart had drifted.
  // Verified: with a spurious column added to Subjects, the startAt(1) variant
  // still reported "All tests passed"; this variant fails with SchemaMismatch.
  test(
    'a database created at v1 validates against the committed schema',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 1);
    },
  );
}
