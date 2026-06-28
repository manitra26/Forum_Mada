import 'dart:convert';
import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

const _jsonHeaders = {
  'Content-Type': 'application/json',
};

// Connexion PostgreSQL
late Connection connection;

Future<void> main(List<String> args) async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  // Récupérer les variables d'environnement
  final port = int.parse(env['PORT'] ?? '8080');
  final host = env['HOST'] ?? 'localhost';

  final dbHost = env['POSTGRES_HOST'] ?? 'localhost';
  final dbPort = env['POSTGRES_PORT'] ?? '5432';
  final dbName = env['POSTGRES_DB'] ?? 'forum_mada';
  final dbUser = env['POSTGRES_USER'] ?? 'postgres';
  final dbPassword = env['POSTGRES_PASSWORD'] ?? '';

  final defaultDatabaseUrl = Uri(
    scheme: 'postgres',
    userInfo: dbPassword.isEmpty ? dbUser : '$dbUser:$dbPassword',
    host: dbHost,
    port: int.parse(dbPort),
    path: '/$dbName',
  ).toString();

  print('Connexion à PostgreSQL...');
  print('Host: $dbHost, Port: $dbPort, DB: $dbName, User: $dbUser');

  try {
    connection = await Connection.openFromUrl(
      env['DATABASE_URL'] ?? defaultDatabaseUrl,
    );
    print('✅ Connecté à PostgreSQL');
  } catch (e) {
    print('❌ Erreur de connexion: $e');
    print(
        'Vérifiez que PostgreSQL est démarré et les identifiants sont corrects');
    return;
  }

  // Initialiser les tables
  await _initDatabase(connection);
  print('✅ Tables initialisées');

  // Créer le routeur
  final router = Router()
    ..get('/api/ping', _pingHandler)
    ..get('/api/admin/stats', _getAdminStats)
    ..get('/api/admin/users', _getAdminUsers)
    ..patch('/api/admin/users/<id>/role', _updateUserRole)
    ..patch('/api/admin/users/<id>/active', _toggleUserActive)
    ..delete('/api/admin/users/<id>', _deleteUser)
    ..get('/api/categories', _getCategories)
    ..post('/api/categories', _createCategory)
    ..patch('/api/categories/<id>', _updateCategory)
    ..delete('/api/categories/<id>', _deleteCategory)
    ..get('/api/topics', _getTopics)
    ..post('/api/topics', _createTopic)
    ..get('/api/topics/<id>', _getTopicById)
    ..patch('/api/topics/<id>/pin', _toggleTopicPinned)
    ..patch('/api/topics/<id>/lock', _toggleTopicLocked)
    ..delete('/api/topics/<id>', _deleteTopic)
    ..post('/api/posts', _createPost)
    ..get('/api/posts/topic/<topicId>', _getPostsByTopic)
    ..post('/api/posts/<id>/like', _togglePostLike)
    ..get('/api/users/<id>', _getUserProfile)
    ..get('/api/users/<id>/topics', _getUserTopics)
    ..get('/api/users/<id>/posts', _getUserPosts)
    ..patch('/api/users/<id>/profile', _updateUserProfile)
    ..post('/api/users/<id>/avatar', _uploadUserAvatar)
    ..get('/uploads/<path|.*>', _serveUpload)
    ..post('/api/register', _registerUser)
    ..post('/api/login', _loginUser);

  // Middleware
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  // Démarrer le serveur
  final server = await shelf_io.serve(handler, host, port);
  print('═══════════════════════════════════════');
  print('   🚀 ForumMada Backend Dart');
  print('═══════════════════════════════════════');
  print('✅ Serveur: http://${server.address.host}:${server.port}');
  print('📚 API: http://${server.address.host}:${server.port}/api/categories');
  print('═══════════════════════════════════════');
}

// ============ HANDLERS ============

Response _pingHandler(Request request) {
  return Response.ok(jsonEncode({'status': 'ok', 'message': 'ForumMada API'}),
      headers: _jsonHeaders);
}

// Statistiques admin
Future<Response> _getAdminStats(Request request) async {
  try {
    final role = request.url.queryParameters['role'];
    if (role != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final usersCount = await connection.execute('SELECT COUNT(*) FROM users');
    final topicsCount = await connection.execute('SELECT COUNT(*) FROM topics');
    final postsCount = await connection.execute('SELECT COUNT(*) FROM posts');

    final popularTopics = await connection.execute('''
      SELECT t.id, t.title, t.views, COUNT(p.id) as posts_count
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id
      GROUP BY t.id
      ORDER BY t.views DESC, posts_count DESC, t.created_at DESC
      LIMIT 5
    ''');

    final dailyActivity = await connection.execute('''
      WITH days AS (
        SELECT generate_series(
          CURRENT_DATE - INTERVAL '6 days',
          CURRENT_DATE,
          INTERVAL '1 day'
        )::date AS day
      )
      SELECT
        days.day,
        COUNT(DISTINCT t.id) as topics_count,
        COUNT(DISTINCT p.id) as posts_count
      FROM days
      LEFT JOIN topics t ON DATE(t.created_at) = days.day
      LEFT JOIN posts p ON DATE(p.created_at) = days.day
      GROUP BY days.day
      ORDER BY days.day
    ''');

    return Response.ok(
      jsonEncode({
        'totals': {
          'users': _toInt(usersCount.first[0]),
          'topics': _toInt(topicsCount.first[0]),
          'posts': _toInt(postsCount.first[0]),
        },
        'popular_topics': popularTopics.map((row) {
          return {
            'id': row[0],
            'title': row[1],
            'views': _toInt(row[2]),
            'posts_count': _toInt(row[3]),
          };
        }).toList(),
        'daily_activity': dailyActivity.map((row) {
          return {
            'date': _dateToIso(row[0]),
            'topics_count': _toInt(row[1]),
            'posts_count': _toInt(row[2]),
          };
        }).toList(),
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String _dateToIso(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  return value?.toString() ?? '';
}

bool _isAdminRequest(Map<String, dynamic> data) {
  return data['role'] == 'admin' || data['admin_role'] == 'admin';
}

Future<Response> _getAdminUsers(Request request) async {
  try {
    final role = request.url.queryParameters['role'];
    if (role != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final requestedPage =
        int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final requestedLimit =
        int.tryParse(request.url.queryParameters['limit'] ?? '10') ?? 10;
    final page = requestedPage < 1 ? 1 : requestedPage;
    final safeLimit = requestedLimit.clamp(1, 50).toInt();
    final search = (request.url.queryParameters['search'] ?? '').trim();
    final offset = (page - 1) * safeLimit;

    final usersParameters = <String, dynamic>{
      'limit': safeLimit,
      'offset': offset,
    };

    final countParameters = <String, dynamic>{};
    var countWhereClause = '';
    var usersWhereClause = '';
    if (search.isNotEmpty) {
      countWhereClause =
          'WHERE LOWER(username) LIKE @search OR LOWER(email) LIKE @search';
      usersWhereClause =
          'WHERE LOWER(u.username) LIKE @search OR LOWER(u.email) LIKE @search';
      final searchValue = '%${search.toLowerCase()}%';
      countParameters['search'] = searchValue;
      usersParameters['search'] = searchValue;
    }

    final countResult = await connection.execute(
      Sql.named('SELECT COUNT(*) FROM users $countWhereClause'),
      parameters: countParameters,
    );

    final usersResult = await connection.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.email,
          u.avatar_url,
          u.role,
          u.is_active,
          u.created_at,
          COUNT(DISTINCT t.id) as topics_count,
          COUNT(DISTINCT p.id) as posts_count
        FROM users u
        LEFT JOIN topics t ON t.user_id = u.id
        LEFT JOIN posts p ON p.user_id = u.id
        $usersWhereClause
        GROUP BY u.id
        ORDER BY u.created_at DESC
        LIMIT @limit OFFSET @offset
      '''),
      parameters: usersParameters,
    );

    return Response.ok(
      jsonEncode({
        'page': page,
        'limit': safeLimit,
        'total': _toInt(countResult.first[0]),
        'users': usersResult.map((row) {
          return {
            'id': row[0],
            'username': row[1],
            'email': row[2],
            'avatar_url': row[3],
            'role': row[4],
            'is_active': row[5],
            'created_at': _dateToIso(row[6]),
            'topics_count': _toInt(row[7]),
            'posts_count': _toInt(row[8]),
          };
        }).toList(),
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _updateUserRole(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (!_isAdminRequest(data)) {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final nextRole = data['next_role'] as String?;
    const allowedRoles = {'user', 'moderator', 'admin'};
    if (!allowedRoles.contains(nextRole)) {
      return Response(400,
          body: jsonEncode({'error': 'Role invalide'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE users
        SET role = @nextRole
        WHERE id = @id
        RETURNING id, username, email, role, is_active, created_at
      '''),
      parameters: {
        'id': int.parse(id),
        'nextRole': nextRole,
      },
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode(_adminUserToJson(result.first)),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _toggleUserActive(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (!_isAdminRequest(data)) {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final isActive = data['is_active'] as bool?;
    if (isActive == null) {
      return Response(400,
          body: jsonEncode({'error': 'Statut requis'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE users
        SET is_active = @isActive
        WHERE id = @id
        RETURNING id, username, email, role, is_active, created_at
      '''),
      parameters: {
        'id': int.parse(id),
        'isActive': isActive,
      },
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode(_adminUserToJson(result.first)),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _deleteUser(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (!_isAdminRequest(data)) {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('DELETE FROM users WHERE id = @id RETURNING id'),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({'message': 'Utilisateur supprime'}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Map<String, dynamic> _adminUserToJson(ResultRow row) {
  return {
    'id': row[0],
    'username': row[1],
    'email': row[2],
    'role': row[3],
    'is_active': row[4],
    'created_at': _dateToIso(row[5]),
  };
}

Future<Response> _getCategories(Request request) async {
  try {
    final results = await connection.execute(
      'SELECT * FROM categories ORDER BY id',
    );

    final categories = results.map((row) {
      return {
        'id': row[0],
        'name': row[1],
        'description': row[2],
        'icon': row[3],
        'color': row[4],
        'slug': row[5],
        'created_at': (row[6] as DateTime?)?.toIso8601String(),
      };
    }).toList();

    return Response.ok(jsonEncode(categories), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Récupérer les sujets
Future<Response> _createCategory(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final name = (data['name'] as String?)?.trim();
    final description = (data['description'] as String?)?.trim();
    final icon = (data['icon'] as String?)?.trim();
    final color = (data['color'] as String?)?.trim();
    final slug = (data['slug'] as String?)?.trim();

    if (name == null || name.isEmpty || slug == null || slug.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Nom et slug requis'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        INSERT INTO categories (name, description, icon, color, slug)
        VALUES (@name, @description, @icon, @color, @slug)
        RETURNING *
      '''),
      parameters: {
        'name': name,
        'description': description ?? '',
        'icon': icon ?? 'chat',
        'color': color ?? '#6C63FF',
        'slug': slug,
      },
    );

    return Response.ok(
      jsonEncode(_categoryToJson(result.first)),
      headers: _jsonHeaders,
    );
  } catch (e) {
    if (e.toString().contains('duplicate') ||
        e.toString().contains('unique')) {
      return Response(400,
          body: jsonEncode({'error': 'Slug deja utilise'}),
          headers: _jsonHeaders);
    }
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _updateCategory(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final name = (data['name'] as String?)?.trim();
    final description = (data['description'] as String?)?.trim();
    final icon = (data['icon'] as String?)?.trim();
    final color = (data['color'] as String?)?.trim();
    final slug = (data['slug'] as String?)?.trim();

    if (name == null || name.isEmpty || slug == null || slug.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Nom et slug requis'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE categories
        SET name = @name,
            description = @description,
            icon = @icon,
            color = @color,
            slug = @slug
        WHERE id = @id
        RETURNING *
      '''),
      parameters: {
        'id': int.parse(id),
        'name': name,
        'description': description ?? '',
        'icon': icon ?? 'chat',
        'color': color ?? '#6C63FF',
        'slug': slug,
      },
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Categorie non trouvee'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode(_categoryToJson(result.first)),
      headers: _jsonHeaders,
    );
  } catch (e) {
    if (e.toString().contains('duplicate') ||
        e.toString().contains('unique')) {
      return Response(400,
          body: jsonEncode({'error': 'Slug deja utilise'}),
          headers: _jsonHeaders);
    }
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _deleteCategory(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('DELETE FROM categories WHERE id = @id RETURNING id'),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Categorie non trouvee'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({'message': 'Categorie supprimee'}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Map<String, dynamic> _categoryToJson(ResultRow row) {
  return {
    'id': row[0],
    'name': row[1],
    'description': row[2],
    'icon': row[3],
    'color': row[4],
    'slug': row[5],
    'created_at': (row[6] as DateTime?)?.toIso8601String(),
  };
}

Future<Response> _getTopics(Request request) async {
  try {
    final categoryId = request.url.queryParameters['category_id'];

    String sql = '''
      SELECT t.*, u.username, COUNT(p.id) as posts_count, COALESCE(c.name, 'Sans categorie') as category_name
      FROM topics t
      JOIN users u ON t.user_id = u.id
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN posts p ON p.topic_id = t.id
    ''';

    if (categoryId != null) {
      sql += ' WHERE t.category_id = @categoryId';
    }

    sql += ' GROUP BY t.id, u.username, c.name ORDER BY t.is_pinned DESC, t.created_at DESC';

    final results = categoryId != null
        ? await connection.execute(
            Sql.named(sql),
            parameters: {'categoryId': int.parse(categoryId)},
          )
        : await connection.execute(sql);

    final topics = results.map((row) {
      return {
        'id': row[0],
        'title': row[1],
        'content': row[2],
        'user_id': row[3],
        'category_id': row[4],
        'views': row[5],
        'is_pinned': row[6],
        'is_locked': row[7],
        'created_at': (row[8] as DateTime?)?.toIso8601String(),
        'updated_at': (row[9] as DateTime?)?.toIso8601String(),
        'username': row[10],
        'posts_count': row[11],
        'category_name': row[12],
      };
    }).toList();

    return Response.ok(jsonEncode(topics), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Créer un sujet
Future<Response> _createTopic(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final title = data['title'] as String?;
    final content = data['content'] as String?;
    final userId = data['user_id'] as int?;
    final categoryId = data['category_id'] as int?;

    if (title == null || title.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Le titre est requis'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''INSERT INTO topics (title, content, user_id, category_id)
         VALUES (@title, @content, @userId, @categoryId)
         RETURNING *'''),
      parameters: {
        'title': title,
        'content': content,
        'userId': userId ?? 1,
        'categoryId': categoryId ?? 1,
      },
    );

    final row = result.first;
    final topic = {
      'id': row[0],
      'title': row[1],
      'content': row[2],
      'user_id': row[3],
      'category_id': row[4],
      'views': row[5],
      'is_pinned': row[6],
      'is_locked': row[7],
      'created_at': (row[8] as DateTime?)?.toIso8601String(),
    };

    return Response.ok(jsonEncode(topic), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Epingler / desenpingler un sujet
Future<Response> _toggleTopicPinned(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE topics
        SET is_pinned = NOT is_pinned, updated_at = CURRENT_TIMESTAMP
        WHERE id = @id
        RETURNING is_pinned
      '''),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Sujet non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({'is_pinned': result.first[0]}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Verrouiller / deverrouiller un sujet
Future<Response> _toggleTopicLocked(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE topics
        SET is_locked = NOT is_locked, updated_at = CURRENT_TIMESTAMP
        WHERE id = @id
        RETURNING is_locked
      '''),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Sujet non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({'is_locked': result.first[0]}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Supprimer un sujet
Future<Response> _deleteTopic(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);

    if (data['role'] != 'admin') {
      return Response(403,
          body: jsonEncode({'error': 'Action reservee aux admins'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('DELETE FROM topics WHERE id = @id RETURNING id'),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Sujet non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({'message': 'Sujet supprime'}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Récupérer un sujet par ID
Future<Response> _getTopicById(Request request, String id) async {
  try {
    await connection.execute(
      Sql.named('UPDATE topics SET views = views + 1 WHERE id = @id'),
      parameters: {'id': int.parse(id)},
    );

    final results = await connection.execute(
      Sql.named('''SELECT t.*, u.username, u.avatar_url, COALESCE(c.name, 'Sans categorie') as category_name
         FROM topics t
         JOIN users u ON t.user_id = u.id
         LEFT JOIN categories c ON t.category_id = c.id
         WHERE t.id = @id'''),
      parameters: {'id': int.parse(id)},
    );

    if (results.isEmpty) {
      return Response(
        404,
        body: jsonEncode({'error': 'Sujet non trouvé'}),
        headers: _jsonHeaders,
      );
    }

    final row = results.first;
    final topic = {
      'id': row[0],
      'title': row[1],
      'content': row[2],
      'user_id': row[3],
      'category_id': row[4],
      'views': row[5],
      'is_pinned': row[6],
      'is_locked': row[7],
      'created_at': (row[8] as DateTime?)?.toIso8601String(),
      'updated_at': (row[9] as DateTime?)?.toIso8601String(),
      'username': row[10],
      'avatar_url': row[11],
      'category_name': row[12],
    };

    return Response.ok(jsonEncode(topic), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Créer un message
Future<Response> _createPost(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final content = data['content'] as String?;
    final userId = data['user_id'] as int?;
    final topicId = data['topic_id'] as int?;

    if (content == null || content.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Le contenu est requis'}),
          headers: _jsonHeaders);
    }

    final topicResult = await connection.execute(
      Sql.named('SELECT is_locked FROM topics WHERE id = @topicId'),
      parameters: {'topicId': topicId},
    );

    if (topicResult.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Sujet non trouve'}),
          headers: _jsonHeaders);
    }

    if (topicResult.first[0] == true) {
      return Response(403,
          body: jsonEncode({'error': 'Sujet verrouille'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''INSERT INTO posts (content, user_id, topic_id)
         VALUES (@content, @userId, @topicId)
         RETURNING *'''),
      parameters: {
        'content': content,
        'userId': userId ?? 1,
        'topicId': topicId,
      },
    );

    final row = result.first;
    final post = {
      'id': row[0],
      'content': row[1],
      'user_id': row[2],
      'topic_id': row[3],
      'likes_count': row[4],
      'created_at': (row[5] as DateTime?)?.toIso8601String(),
      'updated_at': (row[6] as DateTime?)?.toIso8601String(),
    };

    return Response.ok(jsonEncode(post), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Récupérer les messages d'un sujet
Future<Response> _getPostsByTopic(Request request, String topicId) async {
  try {
    final userId = int.tryParse(request.url.queryParameters['user_id'] ?? '');
    final results = await connection.execute(
      Sql.named('''SELECT p.*, u.username, u.avatar_url,
            EXISTS(
              SELECT 1 FROM likes l
              WHERE l.post_id = p.id AND l.user_id = @userId
            ) as user_liked
         FROM posts p
         JOIN users u ON p.user_id = u.id
         WHERE p.topic_id = @topicId
         ORDER BY p.created_at ASC'''),
      parameters: {'topicId': int.parse(topicId), 'userId': userId ?? 0},
    );

    final posts = results.map((row) {
      return {
        'id': row[0],
        'content': row[1],
        'user_id': row[2],
        'topic_id': row[3],
        'likes_count': row[4],
        'created_at': (row[5] as DateTime?)?.toIso8601String(),
        'updated_at': (row[6] as DateTime?)?.toIso8601String(),
        'username': row[7],
        'avatar_url': row[8],
        'user_liked': row[9],
      };
    }).toList();

    return Response.ok(jsonEncode(posts), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// Liker / retirer le like d'un message
Future<Response> _togglePostLike(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final userId = data['user_id'] as int?;
    final postId = int.parse(id);

    if (userId == null) {
      return Response(400,
          body: jsonEncode({'error': 'Utilisateur requis'}),
          headers: _jsonHeaders);
    }

    final existing = await connection.execute(
      Sql.named(
          'SELECT id FROM likes WHERE user_id = @userId AND post_id = @postId'),
      parameters: {'userId': userId, 'postId': postId},
    );

    final liked = existing.isEmpty;

    if (liked) {
      await connection.execute(
        Sql.named('INSERT INTO likes (user_id, post_id) VALUES (@userId, @postId)'),
        parameters: {'userId': userId, 'postId': postId},
      );
      await connection.execute(
        Sql.named('UPDATE posts SET likes_count = likes_count + 1 WHERE id = @postId'),
        parameters: {'postId': postId},
      );
    } else {
      await connection.execute(
        Sql.named(
            'DELETE FROM likes WHERE user_id = @userId AND post_id = @postId'),
        parameters: {'userId': userId, 'postId': postId},
      );
      await connection.execute(
        Sql.named('''
          UPDATE posts
          SET likes_count = GREATEST(likes_count - 1, 0)
          WHERE id = @postId
        '''),
        parameters: {'postId': postId},
      );
    }

    final countResult = await connection.execute(
      Sql.named('SELECT likes_count FROM posts WHERE id = @postId'),
      parameters: {'postId': postId},
    );

    return Response.ok(
      jsonEncode({
        'liked': liked,
        'likes_count': countResult.first[0],
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _getUserProfile(Request request, String id) async {
  try {
    final result = await connection.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.email,
          u.avatar_url,
          u.bio,
          u.role,
          u.is_active,
          u.created_at,
          COUNT(DISTINCT t.id) as topics_count,
          COUNT(DISTINCT p.id) as posts_count
        FROM users u
        LEFT JOIN topics t ON t.user_id = u.id
        LEFT JOIN posts p ON p.user_id = u.id
        WHERE u.id = @id
        GROUP BY u.id
      '''),
      parameters: {'id': int.parse(id)},
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode(_userProfileToJson(result.first)),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _getUserTopics(Request request, String id) async {
  try {
    final results = await connection.execute(
      Sql.named('''
        SELECT
          t.*,
          u.username,
          u.avatar_url,
          COUNT(p.id) as posts_count,
          COALESCE(c.name, 'Sans categorie') as category_name
        FROM topics t
        JOIN users u ON t.user_id = u.id
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN posts p ON p.topic_id = t.id
        WHERE t.user_id = @id
        GROUP BY t.id, u.username, u.avatar_url, c.name
        ORDER BY t.created_at DESC
      '''),
      parameters: {'id': int.parse(id)},
    );

    final topics = results.map((row) {
      return {
        'id': row[0],
        'title': row[1],
        'content': row[2],
        'user_id': row[3],
        'category_id': row[4],
        'views': row[5],
        'is_pinned': row[6],
        'is_locked': row[7],
        'created_at': (row[8] as DateTime?)?.toIso8601String(),
        'updated_at': (row[9] as DateTime?)?.toIso8601String(),
        'username': row[10],
        'avatar_url': row[11],
        'posts_count': _toInt(row[12]),
        'category_name': row[13],
      };
    }).toList();

    return Response.ok(jsonEncode(topics), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _getUserPosts(Request request, String id) async {
  try {
    final results = await connection.execute(
      Sql.named('''
        SELECT
          p.id,
          p.content,
          p.user_id,
          p.topic_id,
          p.likes_count,
          p.created_at,
          p.updated_at,
          u.username,
          u.avatar_url,
          t.title as topic_title
        FROM posts p
        JOIN users u ON p.user_id = u.id
        JOIN topics t ON p.topic_id = t.id
        WHERE p.user_id = @id
        ORDER BY p.created_at DESC
      '''),
      parameters: {'id': int.parse(id)},
    );

    final posts = results.map((row) {
      return {
        'id': row[0],
        'content': row[1],
        'user_id': row[2],
        'topic_id': row[3],
        'likes_count': row[4],
        'created_at': (row[5] as DateTime?)?.toIso8601String(),
        'updated_at': (row[6] as DateTime?)?.toIso8601String(),
        'username': row[7],
        'avatar_url': row[8],
        'topic_title': row[9],
      };
    }).toList();

    return Response.ok(jsonEncode(posts), headers: _jsonHeaders);
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _updateUserProfile(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final requesterId = data['user_id'] as int?;

    if (requesterId == null || requesterId != int.parse(id)) {
      return Response(403,
          body: jsonEncode({'error': 'Modification refusee'}),
          headers: _jsonHeaders);
    }

    final bio = (data['bio'] as String?)?.trim();
    final avatarUrl = (data['avatar_url'] as String?)?.trim();

    if (bio != null && bio.length > 500) {
      return Response(400,
          body: jsonEncode({'error': 'Bio trop longue'}),
          headers: _jsonHeaders);
    }

    final result = await connection.execute(
      Sql.named('''
        UPDATE users
        SET bio = @bio,
            avatar_url = @avatarUrl
        WHERE id = @id
        RETURNING id, username, email, avatar_url, bio, role, is_active, created_at
      '''),
      parameters: {
        'id': int.parse(id),
        'bio': bio?.isEmpty == true ? null : bio,
        'avatarUrl': avatarUrl?.isEmpty == true ? null : avatarUrl,
      },
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    final user = result.first;
    return Response.ok(
      jsonEncode({
        'id': user[0],
        'username': user[1],
        'email': user[2],
        'avatar_url': user[3],
        'bio': user[4],
        'role': user[5],
        'is_active': user[6],
        'created_at': (user[7] as DateTime?)?.toIso8601String(),
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _uploadUserAvatar(Request request, String id) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final requesterId = data['user_id'] as int?;

    if (requesterId == null || requesterId != int.parse(id)) {
      return Response(403,
          body: jsonEncode({'error': 'Upload refuse'}),
          headers: _jsonHeaders);
    }

    final fileName = (data['file_name'] as String?) ?? 'avatar.jpg';
    final contentType = (data['content_type'] as String?) ?? 'image/jpeg';
    final base64Data = data['data'] as String?;

    if (base64Data == null || base64Data.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'Image requise'}),
          headers: _jsonHeaders);
    }

    if (!contentType.startsWith('image/')) {
      return Response(400,
          body: jsonEncode({'error': 'Le fichier doit etre une image'}),
          headers: _jsonHeaders);
    }

    final bytes = base64Decode(base64Data);
    if (bytes.length > 3 * 1024 * 1024) {
      return Response(400,
          body: jsonEncode({'error': 'Image trop lourde, maximum 3 Mo'}),
          headers: _jsonHeaders);
    }

    final extension = _avatarExtension(fileName, contentType);
    final uploadsDir = Directory('uploads/avatars');
    if (!uploadsDir.existsSync()) {
      uploadsDir.createSync(recursive: true);
    }

    final savedName =
        'user_${int.parse(id)}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final savedFile = File('uploads/avatars/$savedName');
    await savedFile.writeAsBytes(bytes);

    final avatarUrl =
        '${request.requestedUri.scheme}://${request.requestedUri.authority}/uploads/avatars/$savedName';

    final result = await connection.execute(
      Sql.named('''
        UPDATE users
        SET avatar_url = @avatarUrl
        WHERE id = @id
        RETURNING id, username, email, avatar_url, bio, role, is_active, created_at
      '''),
      parameters: {
        'id': int.parse(id),
        'avatarUrl': avatarUrl,
      },
    );

    if (result.isEmpty) {
      return Response(404,
          body: jsonEncode({'error': 'Utilisateur non trouve'}),
          headers: _jsonHeaders);
    }

    final user = result.first;
    return Response.ok(
      jsonEncode({
        'id': user[0],
        'username': user[1],
        'email': user[2],
        'avatar_url': user[3],
        'bio': user[4],
        'role': user[5],
        'is_active': user[6],
        'created_at': (user[7] as DateTime?)?.toIso8601String(),
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

Future<Response> _serveUpload(Request request, String path) async {
  final safePath = path.replaceAll('\\', '/');
  if (safePath.contains('..')) {
    return Response.forbidden('Chemin refuse');
  }

  final file = File('uploads/$safePath');
  if (!file.existsSync()) {
    return Response.notFound('Fichier non trouve');
  }

  return Response.ok(
    file.openRead(),
    headers: {
      'Content-Type': _contentTypeForPath(file.path),
      'Cache-Control': 'public, max-age=86400',
    },
  );
}

String _avatarExtension(String fileName, String contentType) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.png') || contentType == 'image/png') return '.png';
  if (lowerName.endsWith('.webp') || contentType == 'image/webp') {
    return '.webp';
  }
  if (lowerName.endsWith('.gif') || contentType == 'image/gif') return '.gif';
  return '.jpg';
}

String _contentTypeForPath(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.png')) return 'image/png';
  if (lowerPath.endsWith('.webp')) return 'image/webp';
  if (lowerPath.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

Map<String, dynamic> _userProfileToJson(ResultRow row) {
  return {
    'id': row[0],
    'username': row[1],
    'email': row[2],
    'avatar_url': row[3],
    'bio': row[4],
    'role': row[5],
    'is_active': row[6],
    'created_at': (row[7] as DateTime?)?.toIso8601String(),
    'topics_count': _toInt(row[8]),
    'posts_count': _toInt(row[9]),
  };
}

// Inscription utilisateur
Future<Response> _registerUser(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final username = data['username'] as String?;
    final email = data['email'] as String?;
    final password = data['password'] as String?;

    if (username == null || email == null || password == null) {
      return Response(400,
          body: jsonEncode({'error': 'Tous les champs sont requis'}),
          headers: _jsonHeaders);
    }

    try {
      // Insérer le nouvel utilisateur
      final result = await connection.execute(
        'INSERT INTO users (username, email, password_hash) VALUES (\$1, \$2, \$3) RETURNING id, username, email, avatar_url, bio, role, is_active, created_at',
        parameters: [username, email, password],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return Response.ok(
          jsonEncode({
            'message': 'Utilisateur créé avec succès',
            'id': row[0],
            'user_id': row[0],
            'username': row[1],
            'email': row[2],
            'avatar_url': row[3],
            'bio': row[4],
            'role': row[5],
            'is_active': row[6],
            'created_at': (row[7] as DateTime?)?.toIso8601String(),
          }),
          headers: _jsonHeaders,
        );
      }
    } on Exception catch (dbError) {
      if (dbError.toString().contains('unique') ||
          dbError.toString().contains('duplicate')) {
        return Response(400,
            body: jsonEncode({'error': 'Cet utilisateur ou email existe déjà'}),
            headers: _jsonHeaders);
      }
      rethrow;
    }

    return Response.internalServerError(
      body:
          jsonEncode({'error': 'Erreur lors de la création de l\'utilisateur'}),
      headers: _jsonHeaders,
    );
  } catch (e) {
    print('❌ Erreur _registerUser: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Erreur serveur: ${e.toString()}'}),
      headers: _jsonHeaders,
    );
  }
}

// Connexion utilisateur
Future<Response> _loginUser(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final email = data['email'] as String?;
    final password = data['password'] as String?;

    if (email == null || password == null) {
      return Response(400,
          body: jsonEncode({'error': 'Email et mot de passe requis'}),
          headers: _jsonHeaders);
    }

    final results = await connection.execute(
      Sql.named(
        'SELECT id, username, email, avatar_url, bio, role, is_active, created_at FROM users WHERE email = @email AND password_hash = @password',
      ),
      parameters: {'email': email, 'password': password},
    );

    if (results.isEmpty) {
      return Response(401,
          body: jsonEncode({'error': 'Email ou mot de passe incorrect'}),
          headers: _jsonHeaders);
    }

    final user = results.first;

    if (user[6] == false) {
      return Response(403,
          body: jsonEncode({'error': 'Compte bloque'}),
          headers: _jsonHeaders);
    }

    return Response.ok(
      jsonEncode({
        'message': 'Connexion réussie',
        'id': user[0],
        'user_id': user[0],
        'username': user[1],
        'email': user[2],
        'avatar_url': user[3],
        'bio': user[4],
        'role': user[5] ?? 'user',
        'is_active': user[6] ?? true,
        'created_at': (user[7] as DateTime?)?.toIso8601String(),
      }),
      headers: _jsonHeaders,
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': e.toString()}),
      headers: _jsonHeaders,
    );
  }
}

// ============ INITIALISATION BASE DE DONNÉES ============

Future<void> _initDatabase(Connection connection) async {
  // Table users
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      email VARCHAR(100) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      avatar_url VARCHAR(255),
      bio TEXT,
      role VARCHAR(20) DEFAULT 'user',
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await connection.execute(
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true',
  );
  await connection.execute(
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255)',
  );
  await connection.execute(
    'ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT',
  );

  // Table categories
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS categories (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      description TEXT,
      icon VARCHAR(50),
      color VARCHAR(20),
      slug VARCHAR(100) UNIQUE NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Vérifier si les catégories existent
  final countResult =
      await connection.execute('SELECT COUNT(*) FROM categories');
  final count = countResult.first[0] as int;

  if (count == 0) {
    await connection.execute('''
      INSERT INTO categories (name, description, icon, color, slug) VALUES
      ('Miaraka', 'Discussions générales sur Madagascar', 'chat', '#FF6B6B', 'general'),
      ('Fampiasana', 'Aide technique et informatique', 'computer', '#4ECDC4', 'tech'),
      ('Kolontsaina', 'Culture, traditions et arts malgaches', 'palette', '#45B7D1', 'culture'),
      ('Fiarahamonina', 'Événements et rencontres', 'calendar', '#96CEB4', 'community'),
      ('Vaovao', 'Actualités de Madagascar', 'newspaper', '#FFEAA7', 'news'),
      ('Varotra', 'Achats et ventes', 'cart', '#DDA0DD', 'marketplace')
    ''');
    print('✅ 6 catégories insérées');
  }

  // Table topics
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS topics (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      content TEXT,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
      views INTEGER DEFAULT 0,
      is_pinned BOOLEAN DEFAULT false,
      is_locked BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Table posts
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS posts (
      id SERIAL PRIMARY KEY,
      content TEXT NOT NULL,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      topic_id INTEGER REFERENCES topics(id) ON DELETE CASCADE,
      likes_count INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  // Table likes
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS likes (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(user_id, post_id)
    )
  ''');

  print('✅ Toutes les tables sont prêtes');
}
