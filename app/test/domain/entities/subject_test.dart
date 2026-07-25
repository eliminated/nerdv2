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
