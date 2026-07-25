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

  test('equality is by id alone, not by field values', () {
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
      name: 'Physics', // deliberately different
      createdAt: now,
      updatedAt: now,
    );

    // Without this case the suite cannot tell id-based equality from
    // full-field equality: the previous test's two instances match on every
    // field, so it passes under either implementation. A future change to
    // value equality would slip through unnoticed.
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
