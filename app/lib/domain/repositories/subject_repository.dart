import '../entities/subject.dart';

abstract interface class SubjectRepository {
  /// Live subjects only — excludes soft-deleted and archived — sorted by name.
  Future<List<Subject>> activeSubjects();

  Stream<List<Subject>> watchActiveSubjects();

  Future<Subject> create({
    required String userId,
    required String name,
    String? color,
    String source,
  });
}
