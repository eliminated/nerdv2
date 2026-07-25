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

  test('the generated id is a UUIDv7, not v4', () async {
    final id = await bootstrap.ensureLocalUser();

    // Canonical 8-4-4-4-12 form; the version nibble is the first character of
    // the third group, at index 14. Without this the suite would accept a v4
    // id and silently violate the client-generated-UUIDv7 constraint.
    expect(id, hasLength(36));
    expect(id[14], '7');
  });

  test('timestamps round-trip to the current instant', () async {
    final before = DateTime.now().toUtc();
    await bootstrap.ensureLocalUser();
    final after = DateTime.now().toUtc();

    final user = (await db.select(db.users).get()).single;

    // Compare instants, not `isUtc`: drift stores epoch seconds and reads back
    // in local time, so `isUtc` is false on the way out even though the stored
    // instant is correct. Second-granularity storage means the bounds need a
    // second of slack on each side.
    final created = user.createdAt.toUtc();
    expect(created.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    expect(created.isAfter(after.add(const Duration(seconds: 1))), isFalse);
    expect(user.updatedAt.toUtc(), created);
  });
}
