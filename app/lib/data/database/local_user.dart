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
  Future<String> ensureLocalUser() async {
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
  }
}
