class Topic {
  final int id;
  final String title;
  final String content;
  final int userId;
  final String username;
  final String? avatarUrl;
  final int categoryId;
  final String categoryName;
  final int views;
  final bool isPinned;
  final bool isLocked;
  final int postsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastPostAt;

  Topic({
    required this.id,
    required this.title,
    required this.content,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.categoryId,
    required this.categoryName,
    required this.views,
    required this.isPinned,
    required this.isLocked,
    required this.postsCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastPostAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? '',
      views: json['views'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      isLocked: json['is_locked'] ?? false,
      postsCount: json['posts_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastPostAt: json['last_post_at'] != null 
          ? DateTime.parse(json['last_post_at']) 
          : null,
    );
  }
}