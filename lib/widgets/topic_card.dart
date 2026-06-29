import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/topic.dart';
import '../providers/auth_provider.dart';
import '../screens/topic_detail_screen.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback? onChanged;

  const TopicCard({
    super.key,
    required this.topic,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final avatarUrl = topic.userId == currentUser?.id
        ? currentUser?.avatarUrl
        : topic.avatarUrl;
    final trimmedAvatarUrl = avatarUrl?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(topic.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    topic.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(topic.content),
          ],
        ),
        leading: CircleAvatar(
          backgroundImage: trimmedAvatarUrl == null || trimmedAvatarUrl.isEmpty
              ? null
              : NetworkImage(trimmedAvatarUrl),
          child: trimmedAvatarUrl == null || trimmedAvatarUrl.isEmpty
              ? Text(topic.username.substring(0, 1).toUpperCase())
              : null,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${topic.postsCount} réponses'),
            const SizedBox(height: 4),
            Icon(topic.isPinned ? Icons.push_pin : Icons.forum),
          ],
        ),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(topic: topic),
            ),
          );
          if (changed == true) {
            onChanged?.call();
          }
        },
      ),
    );
  }
}
