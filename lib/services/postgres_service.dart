import 'package:postgres/postgres.dart';
import '../utils/constants.dart';

class PostgresService {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  Connection? _connection;

  PostgresService({
    this.host = AppConstants.postgresHost,
    this.port = AppConstants.postgresPort,
    this.database = AppConstants.postgresDatabase,
    this.username = AppConstants.postgresUser,
    this.password = AppConstants.postgresPassword,
  });

  Future<Connection> get connection async {
    if (_connection == null) {
      _connection = await Connection.open(
        Endpoint(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password,
        ),
      );
    }
    return _connection!;
  }

  Future<void> open() async {
    await connection;
  }

  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String sql,
    List<dynamic>? values,
  ) async {
    final conn = await connection;
    final result = await conn.execute(sql, parameters: values);
    return result.map((row) => row.toColumnMap()).toList();
  }
}
