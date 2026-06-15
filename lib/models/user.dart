class User {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String role;
  final DateTime createdAt;
  final int topicsCount;
  final int postsCount;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.createdAt,
    this.topicsCount = 0,
    this.postsCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      role: json['role'] ?? 'user',
      createdAt: DateTime.parse(json['created_at']),
      topicsCount: json['topics_count'] ?? 0,
      postsCount: json['posts_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
