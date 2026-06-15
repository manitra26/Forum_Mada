class Post {
  final int id;
  final String content;
  final int userId;
  final String username;
  final String? avatarUrl;
  final int topicId;
  final int likesCount;
  final bool userLiked;
  final DateTime createdAt;
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.content,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.topicId,
    required this.likesCount,
    required this.userLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      content: json['content'],
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      topicId: json['topic_id'],
      likesCount: json['likes_count'] ?? 0,
      userLiked: json['user_liked'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}