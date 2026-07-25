import '../entities/subject.dart';

abstract interface class SubjectRepository {
  /// Live, archived, sorted by name.
  Future<List<Subject>> activeSubjects();

  Stream<List<Subject>> watchActiveSubjects();

  Future<Subject> create({
    required String userId,
    required String name,
    String? color,
    String source,
  });
}
