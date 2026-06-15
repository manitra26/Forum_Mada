import 'package:flutter/material.dart';
import '../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(post.username.substring(0, 1).toUpperCase()),
        ),
        title: Text(post.username),
        subtitle: Text(post.content),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.thumb_up, size: 18),
            const SizedBox(width: 4),
            Text(post.likesCount.toString()),
          ],
        ),
      ),
    );
  }
}
