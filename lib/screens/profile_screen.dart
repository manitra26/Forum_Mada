import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/topic.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/topic_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  User? _profile;
  List<Topic> _topics = [];
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getUserProfile(currentUser.id),
        _apiService.getUserTopics(currentUser.id),
        _apiService.getUserPosts(currentUser.id),
      ]);

      final profile = User.fromJson(results[0] as Map<String, dynamic>);
      if (!mounted) return;
      context.read<AuthProvider>().setUser(profile);
      setState(() {
        _profile = profile;
        _topics = (results[1] as List<dynamic>)
            .map((item) => Topic.fromJson(item as Map<String, dynamic>))
            .toList();
        _posts = (results[2] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditProfile(User user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );

    if (saved == true) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _profile ?? context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil'), centerTitle: true),
      body: user == null
          ? const Center(child: Text('Non connecte'))
          : _buildBody(user),
    );
  }

  Widget _buildBody(User user) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            user: user,
            onEdit: () => _openEditProfile(user),
          ),
          const SizedBox(height: 16),
          _StatsRow(user: user),
          const SizedBox(height: 24),
          _SectionTitle(
            icon: Icons.topic,
            title: 'Sujets crees',
            count: _topics.length,
          ),
          const SizedBox(height: 8),
          if (_topics.isEmpty)
            const _EmptyPanel(text: 'Aucun sujet cree pour le moment')
          else
            for (final topic in _topics)
              TopicCard(
                topic: topic,
                onChanged: _loadProfile,
              ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.forum,
            title: 'Messages postes',
            count: _posts.length,
          ),
          const SizedBox(height: 8),
          if (_posts.isEmpty)
            const _EmptyPanel(text: 'Aucun message poste pour le moment')
          else
            for (final post in _posts) _PostActivityCard(post: post),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.user,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(
                      user.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              user.username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 12),
            Text(
              user.bio?.trim().isEmpty == false
                  ? user.bio!
                  : 'Aucune bio pour le moment',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: user.bio?.trim().isEmpty == false
                    ? null
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
                label: const Text('Modifier le profil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final User user;

  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.topic,
            label: 'Sujets',
            value: '${user.topicsCount}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.forum,
            label: 'Messages',
            value: '${user.postsCount}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.verified_user,
            label: 'Role',
            value: user.role,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Chip(label: Text('$count')),
      ],
    );
  }
}

class _PostActivityCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _PostActivityCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(post['created_at'] as String? ?? '');
    final dateLabel = date == null
        ? 'Date inconnue'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.forum)),
        title: Text(
          post['topic_title'] as String? ?? 'Sujet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              post['content'] as String? ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.favorite_border, size: 16),
                const SizedBox(width: 4),
                Text('${post['likes_count'] ?? 0}'),
                const SizedBox(width: 12),
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(dateLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;

  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(child: Text(text)),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final User user;

  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _bioController;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarContentType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarFileName = picked.name;
      _avatarContentType = picked.mimeType ?? _contentTypeFromName(picked.name);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      var avatarUrl = widget.user.avatarUrl ?? '';
      final avatarBytes = _avatarBytes;
      if (avatarBytes != null) {
        final uploaded = await _apiService.uploadUserAvatar(
          userId: widget.user.id,
          bytes: avatarBytes,
          fileName: _avatarFileName ?? 'avatar.jpg',
          contentType: _avatarContentType ?? 'image/jpeg',
        );
        avatarUrl = uploaded['avatar_url'] as String? ?? avatarUrl;
      }

      await _apiService.updateUserProfile(
        userId: widget.user.id,
        bio: _bioController.text.trim(),
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _contentTypeFromName(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: _avatarBytes != null
                  ? MemoryImage(_avatarBytes!)
                  : widget.user.avatarUrl?.trim().isNotEmpty == true
                      ? NetworkImage(widget.user.avatarUrl!) as ImageProvider
                      : null,
              child: _avatarBytes == null &&
                      widget.user.avatarUrl?.trim().isNotEmpty != true
                  ? Text(widget.user.username.substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickAvatar,
                icon: const Icon(Icons.photo_camera),
                label: Text(
                  _avatarBytes == null
                      ? 'Choisir une photo'
                      : 'Changer la photo',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
