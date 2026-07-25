/// A subject the user studies.
///
/// Domain layer: no Flutter, no Drift imports (architecture.md §3.1).
class Subject {
  const Subject({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.source = 'self',
    this.sourceName,
    this.archived = false,
  });

  final String id;
  final String userId;
  final String name;
  final String? color;

  /// 'school' | 'university' | 'course' | 'self'
  final String source;
  final String? sourceName;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) => other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
