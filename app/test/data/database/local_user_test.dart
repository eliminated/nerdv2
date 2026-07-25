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
