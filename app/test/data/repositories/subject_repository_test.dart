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
      <Object>[
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        subject.id,
      ],
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
    final subscription = repository.watchActiveSubjects().listen(
      (s) => emissions.add(s.length),
    );

    await repository.create(userId: userId, name: 'Physics');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await subscription.cancel();
    expect(emissions.last, 1);
  });
}
