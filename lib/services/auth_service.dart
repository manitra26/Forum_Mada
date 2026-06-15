import '../models/user.dart';
import 'postgres_service.dart';

class AuthService {
  final PostgresService _postgresService = PostgresService();

  Future<User?> login(String email, String password) async {
    try {
      final rows = await _postgresService.query(
        'SELECT id, username, email, role, created_at FROM users WHERE email = \$1 AND password = \$2 LIMIT 1',
        [email, password],
      );

      if (rows.isEmpty) return null;

      final row = rows.first;
      return User(
        id: row['id'] as int,
        username: row['username'] as String,
        email: row['email'] as String,
        role: row['role'] as String? ?? 'user',
        createdAt: row['created_at'] is DateTime
            ? row['created_at'] as DateTime
            : DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );
    } catch (e) {
      // ignore: avoid_print
      print('DB Error: $e');
      return null;
    }
  }

  Future<bool> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }
}
