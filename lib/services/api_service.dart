import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api';
  
  // Récupérer les catégories
  Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur getCategories: $e');
      throw Exception('Erreur de connexion au serveur');
    }
  }
  
  // Récupérer les sujets
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
  
  // Créer un sujet
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
    throw Exception('Erreur création sujet');
  }
  
  // Connexion
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
  
  // Inscription
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
}