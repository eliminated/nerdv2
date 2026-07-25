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
  // `GeneratedHelper` at the target version. That reference comes from
  // test/generated_migrations/schema_v1.dart, which `drift_dev schema generate`
  // derives from the committed drift_schemas/drift_schema_v1.json — the JSON is
  // NOT read directly here, so the two artifacts must always be regenerated
  // together. It compares that reference against the schema it reads out of
  // `sqlite_master` for the database it is handed.
  //
  // The database therefore MUST be empty. An empty database opens with
  // user_version 0, so drift runs `onCreate` -> `createAll()`, building the
  // tables from the live generated code. That is the comparison we want:
  // tables.dart against the committed snapshot.
  //
  // Do NOT seed it from `verifier.startAt(1)`. That would pre-create the tables
  // from the snapshot, drift would run no migration (stored version already
  // equals the target), and both sides of the comparison would come from the
  // snapshot — the test would pass no matter how far tables.dart had drifted.
  // Verified: with a spurious column added to Subjects, the startAt(1) variant
  // still reported "All tests passed"; this variant fails with SchemaMismatch.
  //
  // `validateDropped: true` is REQUIRED, not optional hardening. It defaults to
  // false, and find_differences.dart wires the *entity-level* comparison to it
  // (`validateActualInReference: options.validateDropped`) while defaulting the
  // *column-level* one to true. So with the default, an added COLUMN fails the
  // test but an added TABLE or INDEX does not — precisely the change shape this
  // project's additive-only migration law makes most likely. Verified: with a
  // spurious table added, the default-options variant still reported "All tests
  // passed"; with validateDropped it fails naming the table.
  test(
    'a database created at v1 validates against the committed schema',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await verifier.migrateAndValidate(
        db,
        1,
        options: const ValidationOptions(validateDropped: true),
      );
    },
  );
}
