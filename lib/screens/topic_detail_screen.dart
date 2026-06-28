import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../models/topic.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';

class TopicDetailScreen extends StatefulWidget {
  final Topic topic;

  const TopicDetailScreen({super.key, required this.topic});

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _replyController = TextEditingController();
  late Topic _topic;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    _loadPosts();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = context.read<AuthProvider>().user;
      final postsJson = await _apiService.getPostsByTopic(
        _topic.id,
        userId: user?.id,
      );
      setState(() {
        _posts = postsJson
            .map((json) => Post.fromJson(json as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _topic.isLocked) return;

    final user = context.read<AuthProvider>().user;
    setState(() => _isSending = true);

    try {
      await _apiService.createPost(
        content: content,
        userId: user?.id ?? 1,
        topicId: _topic.id,
      );
      _replyController.clear();
      await _loadPosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _toggleLike(Post post) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final response = await _apiService.togglePostLike(
        postId: post.id,
        userId: user.id,
      );

      setState(() {
        _posts = _posts.map((item) {
          if (item.id != post.id) return item;
          return item.copyWith(
            likesCount: response['likes_count'] as int,
            userLiked: response['liked'] as bool,
          );
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _togglePinned() async {
    final role = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      final response = await _apiService.toggleTopicPinned(
        topicId: _topic.id,
        role: role,
      );
      setState(() {
        _topic = _topic.copyWith(isPinned: response['is_pinned'] as bool);
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _toggleLocked() async {
    final role = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      final response = await _apiService.toggleTopicLocked(
        topicId: _topic.id,
        role: role,
      );
      setState(() {
        _topic = _topic.copyWith(isLocked: response['is_locked'] as bool);
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteTopic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le sujet'),
        content: const Text('Cette action supprimera aussi ses reponses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final role = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      await _apiService.deleteTopic(topicId: _topic.id, role: role);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_topic.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_topic.isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.push_pin),
            ),
          if (_topic.isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.lock),
            ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'pin') _togglePinned();
                if (value == 'lock') _toggleLocked();
                if (value == 'delete') _deleteTopic();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Text(_topic.isPinned ? 'Desepingler' : 'Epingler'),
                ),
                PopupMenuItem(
                  value: 'lock',
                  child: Text(_topic.isLocked ? 'Deverrouiller' : 'Verrouiller'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildContent()),
          _buildReplyComposer(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPosts,
              child: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _topic.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('${_posts.length} reponses')),
              if (_topic.isPinned) const Chip(label: Text('Epingle')),
              if (_topic.isLocked) const Chip(label: Text('Verrouille')),
            ],
          ),
          const SizedBox(height: 16),
          if (_posts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('Aucune reponse pour le moment')),
            )
          else
            ..._posts.map(
              (post) => PostCard(
                post: post,
                onLike: () => _toggleLike(post),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer() {
    if (_topic.isLocked) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: const Text('Sujet verrouille: les reponses sont fermees.'),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ajouter une reponse',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isSending ? null : _sendReply,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
