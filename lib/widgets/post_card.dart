import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLike;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final avatarUrl = post.userId == currentUser?.id
        ? currentUser?.avatarUrl
        : post.avatarUrl;
    final trimmedAvatarUrl = avatarUrl?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: trimmedAvatarUrl == null || trimmedAvatarUrl.isEmpty
              ? null
              : NetworkImage(trimmedAvatarUrl),
          child: trimmedAvatarUrl == null || trimmedAvatarUrl.isEmpty
              ? Text(post.username.substring(0, 1).toUpperCase())
              : null,
        ),
        title: Text(post.username),
        subtitle: Text(post.content),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onLike,
              icon: Icon(
                post.userLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                size: 18,
              ),
            ),
            const SizedBox(width: 4),
            Text(post.likesCount.toString()),
          ],
        ),
      ),
    );
  }
}
