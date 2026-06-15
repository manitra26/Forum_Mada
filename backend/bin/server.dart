import 'dart:convert';
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
    ..get('/api/categories', _getCategories)
    ..get('/api/topics', _getTopics)
    ..post('/api/topics', _createTopic)
    ..get('/api/topics/<id>', _getTopicById)
    ..post('/api/posts', _createPost)
    ..get('/api/posts/topic/<topicId>', _getPostsByTopic)
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

// Récupérer toutes les catégories
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
Future<Response> _getTopics(Request request) async {
  try {
    final categoryId = request.url.queryParameters['category_id'];

    String sql = '''
      SELECT t.*, u.username, COUNT(p.id) as posts_count
      FROM topics t
      JOIN users u ON t.user_id = u.id
      LEFT JOIN posts p ON p.topic_id = t.id
    ''';

    if (categoryId != null) {
      sql += ' WHERE t.category_id = @categoryId';
    }

    sql += ' GROUP BY t.id, u.username ORDER BY t.created_at DESC';

    final results = categoryId != null
        ? await connection
            .execute(sql, parameters: {'categoryId': int.parse(categoryId)})
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
      '''INSERT INTO topics (title, content, user_id, category_id) 
         VALUES (@title, @content, @userId, @categoryId) 
         RETURNING *''',
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

// Récupérer un sujet par ID
Future<Response> _getTopicById(Request request, String id) async {
  try {
    await connection.execute(
      'UPDATE topics SET views = views + 1 WHERE id = @id',
      parameters: {'id': int.parse(id)},
    );

    final results = await connection.execute(
      '''SELECT t.*, u.username, u.avatar_url, c.name as category_name
         FROM topics t
         JOIN users u ON t.user_id = u.id
         JOIN categories c ON t.category_id = c.id
         WHERE t.id = @id''',
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

    final result = await connection.execute(
      '''INSERT INTO posts (content, user_id, topic_id) 
         VALUES (@content, @userId, @topicId) 
         RETURNING *''',
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
    final results = await connection.execute(
      '''SELECT p.*, u.username, u.avatar_url
         FROM posts p
         JOIN users u ON p.user_id = u.id
         WHERE p.topic_id = @topicId
         ORDER BY p.created_at ASC''',
      parameters: {'topicId': int.parse(topicId)},
    );

    final posts = results.map((row) {
      return {
        'id': row[0],
        'content': row[1],
        'user_id': row[2],
        'topic_id': row[3],
        'likes_count': row[4],
        'created_at': (row[5] as DateTime?)?.toIso8601String(),
        'username': row[6],
        'avatar_url': row[7],
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
        'INSERT INTO users (username, email, password_hash) VALUES (\$1, \$2, \$3) RETURNING id, username, email, role',
        parameters: [username, email, password],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        return Response.ok(
          jsonEncode({
            'message': 'Utilisateur créé avec succès',
            'user_id': row[0],
            'username': row[1],
            'email': row[2],
            'role': row[3],
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
      'SELECT * FROM users WHERE email = @email AND password_hash = @password',
      parameters: {'email': email, 'password': password},
    );

    if (results.isEmpty) {
      return Response(401,
          body: jsonEncode({'error': 'Email ou mot de passe incorrect'}),
          headers: _jsonHeaders);
    }

    final user = results.first;

    return Response.ok(
      jsonEncode({
        'message': 'Connexion réussie',
        'user_id': user[0],
        'username': user[1],
        'email': user[2],
        'role': user[4] ?? 'user',
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ''');

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
