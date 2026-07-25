import 'package:uuid/uuid.dart';

import 'database.dart';

/// Guarantees exactly one local user row.
///
/// There is no auth before v1.0 (masterplan decision 3), but every
/// `user_id` foreign key is populated from day one so that adding a
/// server later needs no migration (decision 4).
class LocalUserBootstrap {
  LocalUserBootstrap(this._db);

  final AppDatabase _db;

  static const _uuid = Uuid();

  /// Returns the local user's id, creating the row if absent.
  ///
  /// Wrapped in a transaction because the read-then-insert is otherwise not
  /// atomic: two concurrent callers could both see an empty table and each
  /// insert a row, breaking the guarantee in this class's doc comment. The
  /// `UNIQUE` on `users.email` is no backstop — SQLite permits multiple NULLs
  /// and the local user has no email.
  Future<String> ensureLocalUser() {
    return _db.transaction(() async {
      // Unconditional select is safe only because this table holds exactly one
      // row by design. If two rows ever existed, `getSingleOrNull()` throws
      // rather than silently picking one; failing loud is correct here.
      final existing = await _db.select(_db.users).getSingleOrNull();
      if (existing != null) {
        return existing.id;
      }

      final now = DateTime.now().toUtc();
      final id = _uuid.v7();

      await _db.into(_db.users).insert(
            UsersCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
            ),
          );

      return id;
    });
  }
}
