import 'package:flutter/material.dart';
import '../models/topic.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;

  const TopicCard({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(topic.title),
        subtitle: Text(topic.content),
        leading: CircleAvatar(
          child: Text(topic.username.substring(0, 1).toUpperCase()),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${topic.postsCount} réponses'),
            const SizedBox(height: 4),
            Icon(topic.isPinned ? Icons.push_pin : Icons.forum),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(context, '/topic-detail', arguments: topic);
        },
      ),
    );
  }
}
