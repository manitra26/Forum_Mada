import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api';

  Future<Map<String, dynamic>> getAdminStats({required String role}) async {
    final uri = Uri.parse('$baseUrl/admin/stats').replace(
      queryParameters: {'role': role},
    );
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur chargement statistiques admin');
  }

  Future<Map<String, dynamic>> getAdminUsers({
    required String role,
    required int page,
    required int limit,
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/admin/users').replace(
      queryParameters: {
        'role': role,
        'page': '$page',
        'limit': '$limit',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur chargement utilisateurs'));
  }

  Future<Map<String, dynamic>> updateUserRole({
    required int userId,
    required String adminRole,
    required String nextRole,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/role'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'admin_role': adminRole,
        'next_role': nextRole,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur changement role');
  }

  Future<Map<String, dynamic>> updateUserActive({
    required int userId,
    required String adminRole,
    required bool isActive,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/users/$userId/active'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'admin_role': adminRole,
        'is_active': isActive,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erreur mise a jour utilisateur');
  }

  Future<void> deleteUser({
    required int userId,
    required String adminRole,
  }) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$baseUrl/admin/users/$userId'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'admin_role': adminRole});

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Erreur suppression utilisateur');
    }
  }

  Future<List<dynamic>> getCategories({int? userId}) async {
    try {
      final uri = Uri.parse('$baseUrl/categories').replace(
        queryParameters: {
          if (userId != null) 'user_id': '$userId',
        },
      );
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Erreur: ${response.statusCode}');
    } catch (e) {
      print('Erreur getCategories: $e');
      throw Exception('Erreur de connexion au serveur');
    }
  }

  Future<Map<String, dynamic>> toggleCategoryFollow({
    required int categoryId,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories/$categoryId/follow'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur suivi categorie'));
  }

  Future<Map<String, dynamic>> createCategory({
    required String name,
    required String description,
    required String icon,
    required String color,
    required String slug,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'slug': slug,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur creation categorie');
  }

  Future<Map<String, dynamic>> updateCategory({
    required int id,
    required String name,
    required String description,
    required String icon,
    required String color,
    required String slug,
    required String role,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/categories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'slug': slug,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur modification categorie');
  }

  Future<void> deleteCategory({
    required int id,
    required String role,
  }) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$baseUrl/categories/$id'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'role': role});

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Erreur suppression categorie');
    }
  }

  Future<List<dynamic>> getTopics({int? categoryId}) async {
    String url = '$baseUrl/topics';
    if (categoryId != null) {
      url += '?category_id=$categoryId';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur chargement sujets');
  }

  Future<Map<String, dynamic>> createTopic({
    required String title,
    required String content,
    required int userId,
    required int categoryId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/topics'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': title,
        'content': content,
        'user_id': userId,
        'category_id': categoryId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur creation sujet');
  }

  Future<List<dynamic>> getPostsByTopic(int topicId, {int? userId}) async {
    var url = '$baseUrl/posts/topic/$topicId';
    if (userId != null) {
      url += '?user_id=$userId';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur chargement reponses');
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    required int userId,
    required int topicId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'content': content,
        'user_id': userId,
        'topic_id': topicId,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur creation reponse');
  }

  Future<Map<String, dynamic>> togglePostLike({
    required int postId,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur like reponse');
  }

  Future<Map<String, dynamic>> toggleTopicPinned({
    required int topicId,
    required String role,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/topics/$topicId/pin'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'role': role}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Action admin refusee');
  }

  Future<Map<String, dynamic>> toggleTopicLocked({
    required int topicId,
    required String role,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/topics/$topicId/lock'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'role': role}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Action admin refusee');
  }

  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur chargement profil'));
  }

  Future<List<dynamic>> getUserTopics(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/topics'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur chargement sujets'));
  }

  Future<List<dynamic>> getUserPosts(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/posts'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur chargement messages'));
  }

  Future<List<dynamic>> getUserNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/notifications'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur chargement notifications'));
  }

  Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur lecture notification'));
  }

  Future<void> markAllNotificationsRead(int userId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId/notifications/read-all'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Erreur lecture notifications'));
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String bio,
    required String avatarUrl,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/$userId/profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'bio': bio,
        'avatar_url': avatarUrl,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur modification profil'));
  }

  Future<Map<String, dynamic>> uploadUserAvatar({
    required int userId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/avatar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'file_name': fileName,
        'content_type': contentType,
        'data': base64Encode(bytes),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_errorMessage(response, 'Erreur upload avatar'));
  }

  Future<void> deleteTopic({
    required int topicId,
    required String role,
  }) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('$baseUrl/topics/$topicId'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'role': role});

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Suppression refusee');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Email ou mot de passe incorrect');
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Erreur lors de l\'inscription');
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['error']?.toString();
      if (message != null && message.isNotEmpty) {
        return '$fallback: $message';
      }
    } catch (_) {
      // Keep the fallback below when the server did not return JSON.
    }
    return '$fallback (${response.statusCode})';
  }
}
