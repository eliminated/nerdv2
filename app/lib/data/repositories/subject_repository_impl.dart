import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/subject.dart';
import '../../domain/repositories/subject_repository.dart';
import '../database/database.dart';

class SubjectRepositoryImpl implements SubjectRepository {
  SubjectRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  SimpleSelectStatement<$SubjectsTable, SubjectRow> _activeQuery() {
    return _db.select(_db.subjects)
      ..where((t) => t.deletedAt.isNull() & t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  }

  @override
  Future<List<Subject>> activeSubjects() async {
    final rows = await _activeQuery().get();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<Subject>> watchActiveSubjects() {
    return _activeQuery().watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Subject> create({
    required String userId,
    required String name,
    String? color,
    String source = 'self',
  }) async {
    final now = DateTime.now().toUtc();
    final subject = Subject(
      id: _uuid.v7(),
      userId: userId,
      name: name,
      color: color,
      source: source,
      createdAt: now,
      updatedAt: now,
    );

    await _db
        .into(_db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: subject.id,
            userId: subject.userId,
            name: subject.name,
            color: Value(subject.color),
            source: Value(subject.source),
            createdAt: subject.createdAt,
            updatedAt: subject.updatedAt,
          ),
        );

    return subject;
  }

  Subject _toEntity(SubjectRow row) => Subject(
    id: row.id,
    userId: row.userId,
    name: row.name,
    color: row.color,
    source: row.source,
    sourceName: row.sourceName,
    archived: row.archived,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
