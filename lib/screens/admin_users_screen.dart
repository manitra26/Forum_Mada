import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  int _page = 1;
  int _limit = 10;
  int _total = 0;

  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _limit).ceil();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({int? page}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (page != null) _page = page;
    });

    try {
      final role = context.read<AuthProvider>().user?.role ?? 'user';
      final result = await _apiService.getAdminUsers(
        role: role,
        page: _page,
        limit: _limit,
        search: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _users = result['users'] as List<dynamic>? ?? [];
        _total = result['total'] as int? ?? 0;
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

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      _loadUsers(page: 1);
    });
  }

  Future<void> _changeRole(Map<String, dynamic> user, String nextRole) async {
    final adminRole = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      await _apiService.updateUserRole(
        userId: user['id'] as int,
        adminRole: adminRole,
        nextRole: nextRole,
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _setActive(Map<String, dynamic> user, bool isActive) async {
    final adminRole = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      await _apiService.updateUserActive(
        userId: user['id'] as int,
        adminRole: adminRole,
        isActive: isActive,
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer utilisateur'),
          content: Text('Supprimer "${user["username"]}" definitivement ?'),
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
        );
      },
    );

    if (confirm != true) return;

    final adminRole = context.read<AuthProvider>().user?.role ?? 'user';
    try {
      await _apiService.deleteUser(
        userId: user['id'] as int,
        adminRole: adminRole,
      );
      await _loadUsers(page: _page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur supprime')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadUsers(page: 1);
                        },
                      ),
                labelText: 'Rechercher par nom ou email',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
          _PaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            onPrevious: _page <= 1 ? null : () => _loadUsers(page: _page - 1),
            onNext: _page >= _totalPages
                ? null
                : () => _loadUsers(page: _page + 1),
            limit: _limit,
            onLimitChanged: (value) {
              if (value == null) return;
              setState(() => _limit = value);
              _loadUsers(page: 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur trouve'));
    }

    final currentUserId = context.read<AuthProvider>().user?.id;

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index] as Map<String, dynamic>;
          return _UserAdminCard(
            user: user,
            isCurrentUser: user['id'] == currentUserId,
            onRoleChanged: (role) => _changeRole(user, role),
            onActiveChanged: (active) => _setActive(user, active),
            onDelete: () => _deleteUser(user),
          );
        },
      ),
    );
  }
}

class _UserAdminCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCurrentUser;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;

  const _UserAdminCard({
    required this.user,
    required this.isCurrentUser,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] as bool? ?? true;
    final role = user['role'] as String? ?? 'user';
    final currentUser = context.watch<AuthProvider>().user;
    final avatarUrl = user['id'] == currentUser?.id
        ? currentUser?.avatarUrl
        : user['avatar_url'] as String?;
    final trimmedAvatarUrl = avatarUrl?.trim();
    final hasAvatar = trimmedAvatarUrl != null && trimmedAvatarUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    hasAvatar ? NetworkImage(trimmedAvatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        (user['username'] as String? ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
              ),
              title: Text(user['username'] as String? ?? 'Utilisateur'),
              subtitle: Text(user['email'] as String? ?? ''),
              trailing: IconButton(
                onPressed: isCurrentUser ? null : onDelete,
                icon: const Icon(Icons.delete),
                color: Colors.red,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('user')),
                    DropdownMenuItem(
                        value: 'moderator', child: Text('moderator')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                  ],
                  onChanged: isCurrentUser || !isActive
                      ? null
                      : (value) {
                          if (value != null) onRoleChanged(value);
                        },
                ),
                FilterChip(
                  selected: isActive,
                  avatar: Icon(
                    isActive ? Icons.check_circle : Icons.block,
                    size: 18,
                  ),
                  label: Text(isActive ? 'Actif' : 'Banni'),
                  onSelected: isCurrentUser
                      ? null
                      : (selected) => onActiveChanged(!isActive),
                ),
                Chip(
                  avatar: const Icon(Icons.topic, size: 18),
                  label: Text('${user['topics_count'] ?? 0} sujets'),
                ),
                Chip(
                  avatar: const Icon(Icons.forum, size: 18),
                  label: Text('${user['posts_count'] ?? 0} messages'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int limit;
  final ValueChanged<int?> onLimitChanged;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.limit,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('$total utilisateurs'),
              const Spacer(),
              DropdownButton<int>(
                value: limit,
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: onLimitChanged,
              ),
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$page/$totalPages'),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
