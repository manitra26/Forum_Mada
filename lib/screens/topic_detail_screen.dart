import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/topic.dart';
import '../widgets/post_card.dart';

class TopicDetailScreen extends StatelessWidget {
  final Topic topic;

  const TopicDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final posts = List.generate(
      4,
      (index) => Post(
        id: index,
        content: 'Réponse ${index + 1} sur le sujet.',
        userId: index + 1,
        username: 'User${index + 1}',
        avatarUrl: null,
        topicId: topic.id,
        likesCount: index * 3,
        userLiked: false,
        createdAt: DateTime.now().subtract(Duration(hours: index * 2 + 1)),
        updatedAt: DateTime.now().subtract(Duration(hours: index * 2 + 1)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(topic.content, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) => PostCard(post: posts[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
