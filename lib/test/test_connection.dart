import 'package:forum_mada/services/postgres_service.dart';

void main() async {
  print('🔄 Test de connexion PostgreSQL pour ForumMada...\n');

  final service = PostgresService();

  try {
    // 1. Tester la connexion
    print('📡 1. Connexion à la base de données...');
    await service.open();
    print('   ✅ Connecté avec succès!\n');

    // 2. Récupérer les catégories
    print('📚 2. Récupération des catégories...');
    final categories = await service.query('SELECT * FROM categories', null);

    if (categories.isNotEmpty) {
      print('   ✅ ${categories.length} catégories trouvées:\n');
      for (var cat in categories) {
        print('   📌 ${cat['name']} - ${cat['description']}');
      }
    } else {
      print('   ⚠️ Aucune catégorie trouvée');
    }

    print('\n✅ TOUS LES TESTS RÉUSSIS!');
    print('💡 Votre base de données ForumMada est prête!');
  } catch (e) {
    print('❌ ERREUR: $e');
    print('\n💡 Vérifications:');
    print('   1. PostgreSQL est-il démarré?');
    print('   2. La base "forum_mada" existe-t-elle?');
    print('   3. Les identifiants dans constants.dart sont-ils corrects?');
  } finally {
    await service.close();
  }
}
