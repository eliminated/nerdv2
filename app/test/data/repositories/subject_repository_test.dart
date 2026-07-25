import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nerdyapp/data/database/database.dart';
import 'package:nerdyapp/data/database/local_user.dart';
import 'package:nerdyapp/data/repositories/subject_repository_impl.dart';
import 'package:nerdyapp/domain/entities/subject.dart';

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

    // Not merely isNotEmpty: that accepts a v4 id, a counter, or any string,
    // leaving the client-generated-UUIDv7 constraint untested. Same assertions
    // as local_user_test.dart, for the same reason.
    expect(created.id, hasLength(36));
    expect(created.id[14], '7');
    expect(created.name, 'Physics');
    expect(created.userId, userId);
    expect(created.source, 'self');
    expect(created.archived, isFalse);
  });

  test('lists created subjects sorted by name', () async {
    await repository.create(userId: userId, name: 'Physics');
    await repository.create(userId: userId, name: 'Algebra');

    final names = (await repository.activeSubjects())
        .map((s) => s.name)
        .toList();
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

  test('watchActiveSubjects emits the new subject after an insert', () async {
    // `emitsThrough` subscribes immediately and waits for a matching event,
    // ignoring earlier ones. That avoids both failure modes of a fixed
    // `Future.delayed`: flaking under CI load if the emission is slow, and
    // depending on whether drift's initial empty emission lands before or
    // after the insert.
    final expectation = expectLater(
      repository.watchActiveSubjects(),
      emitsThrough(
        predicate<List<Subject>>(
          (subjects) =>
              subjects.length == 1 && subjects.single.name == 'Physics',
          'exactly one subject named Physics',
        ),
      ),
    );

    await repository.create(userId: userId, name: 'Physics');
    await expectation;
  });
}
