class AppConstants {
  static const String appName = 'ForumMada';
  
  // PostgreSQL Configuration
  static const String postgresHost = 'localhost';
  static const int postgresPort = 5432;
  static const String postgresDatabase = 'forum_mada';
  static const String postgresUser = 'postgres';
  static const String postgresPassword = r'$manitra2026'; // À MODIFIER!
  
  // Tables
  static const String tableUsers = 'users';
  static const String tableCategories = 'categories';
  static const String tableTopics = 'topics';
  static const String tablePosts = 'posts';
  static const String tableLikes = 'likes';
}