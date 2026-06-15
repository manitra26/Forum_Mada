class Category {
  final int id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final String slug;
  final int topicsCount;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.slug,
    this.topicsCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'chat',
      color: json['color'] ?? '#FF6B6B',
      slug: json['slug'],
      topicsCount: json['topics_count'] ?? 0,
    );
  }
}