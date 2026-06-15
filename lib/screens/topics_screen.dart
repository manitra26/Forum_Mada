import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../widgets/topic_card.dart';

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topics = List.generate(
      5,
      (index) => Topic(
        id: index,
        title: 'Sujet intéressant ${index + 1}',
        content: 'Description courte du sujet ${index + 1}.',
        userId: 1,
        username: 'Auteur${index + 1}',
        avatarUrl: null,
        categoryId: 1,
        categoryName: 'Actualités',
        views: 120 + index * 10,
        isPinned: index == 0,
        isLocked: false,
        postsCount: 8 + index,
        createdAt: DateTime.now().subtract(Duration(hours: index * 4)),
        updatedAt: DateTime.now().subtract(Duration(hours: index * 2)),
        lastPostAt: DateTime.now().subtract(Duration(hours: index + 1)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sujets'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          return TopicCard(topic: topics[index]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/create-topic'),
        icon: const Icon(Icons.add),
        label: const Text('Créer un sujet'),
      ),
    );
  }
}
