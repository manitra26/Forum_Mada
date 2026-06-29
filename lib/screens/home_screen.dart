import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/formatters.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'topics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  List<Map<String, dynamic>> _notifications = [];
  bool _notificationsLoading = false;
  String? _notificationsError;
  int? _connectedUserId;

  int get _unreadNotifications =>
      _notifications.where((item) => item['is_read'] != true).length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null && userId != _connectedUserId) {
      _connectedUserId = userId;
      _loadNotifications(userId);
      _notificationSubscription?.cancel();
      _notificationSubscription = _socketService.notifications.listen(
        _handleRealtimeNotification,
      );
      _socketService.connect(userId: userId);
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _socketService.close();
    super.dispose();
  }

  Future<void> _loadNotifications(int userId) async {
    setState(() {
      _notificationsLoading = true;
      _notificationsError = null;
    });

    try {
      final result = await _apiService.getUserNotifications(userId);
      if (!mounted) return;
      setState(() {
        _notifications = result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _notificationsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notificationsError = e.toString();
        _notificationsLoading = false;
      });
    }
  }

  void _handleRealtimeNotification(Map<String, dynamic> notification) {
    if (!mounted) return;
    setState(() {
      _notifications.removeWhere((item) => item['id'] == notification['id']);
      _notifications.insert(0, notification);
    });
  }

  Future<void> _markNotificationRead(Map<String, dynamic> notification) async {
    final id = notification['id'] as int?;
    if (id == null || notification['is_read'] == true) return;

    setState(() {
      notification['is_read'] = true;
    });

    try {
      final updated = await _apiService.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        final index = _notifications.indexWhere((item) => item['id'] == id);
        if (index != -1) {
          _notifications[index] = updated;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        notification['is_read'] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final userId = _connectedUserId;
    if (userId == null) return;
    final previous = _notifications
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    setState(() {
      _notifications = _notifications.map((item) {
        return {...item, 'is_read': true};
      }).toList();
    });

    try {
      await _apiService.markAllNotificationsRead(userId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notifications = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 1:
        return const CategoriesPage();
      case 2:
        return NotificationsPage(
          notifications: _notifications,
          isLoading: _notificationsLoading,
          error: _notificationsError,
          onRefresh: () async {
            final userId = _connectedUserId;
            if (userId != null) {
              await _loadNotifications(userId);
            }
          },
          onNotificationTap: _markNotificationRead,
          onMarkAllRead: _markAllNotificationsRead,
        );
      default:
        return const HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final avatarUrl = user?.avatarUrl?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ForumMada'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Recherche',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(user?.username ?? 'Invite'),
                accountEmail: Text(user?.email ?? 'Non connecte'),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                      ? null
                      : NetworkImage(avatarUrl),
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          user?.username.substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Accueil'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Categories'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 2);
                },
              ),
              if (authProvider.user?.role == 'admin')
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard admin'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
              if (authProvider.user?.role == 'admin')
                ListTile(
                  leading: const Icon(Icons.manage_accounts),
                  title: const Text('Gestion utilisateurs'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUsersScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Parametres'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Deconnexion',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  final localContext = context;
                  await authProvider.logout();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(localContext, '/');
                },
              ),
            ],
          ),
        ),
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: _NotificationNavIcon(count: _unreadNotifications),
            label: 'Notifications',
          ),
        ],
      ),
    );
  }
}

class _NotificationNavIcon extends StatelessWidget {
  final int count;

  const _NotificationNavIcon({required this.count});

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: const Icon(Icons.notifications),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onNotificationTap;
  final Future<void> Function() onMarkAllRead;

  const NotificationsPage({
    super.key,
    required this.notifications,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onNotificationTap,
    required this.onMarkAllRead,
  });

  int get _unreadCount =>
      notifications.where((item) => item['is_read'] != true).length;

  @override
  Widget build(BuildContext context) {
    if (isLoading && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_off, size: 56),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (_unreadCount > 0)
                TextButton.icon(
                  onPressed: onMarkAllRead,
                  icon: const Icon(Icons.done_all),
                  label: const Text('Tout lire'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (notifications.isEmpty)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 64),
                    SizedBox(height: 12),
                    Text('Aucune notification'),
                  ],
                ),
              ),
            )
          else
            for (final notification in notifications)
              _NotificationTile(
                notification: notification,
                onTap: () => onNotificationTap(notification),
              ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = notification['is_read'] == true;
    final createdAt = DateTime.tryParse(
      notification['created_at']?.toString() ?? '',
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _typeColor(colorScheme).withAlpha(32),
          child: Icon(
            _typeIcon(),
            color: _typeColor(colorScheme),
          ),
        ),
        title: Text(
          notification['content']?.toString() ?? '',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
          ),
        ),
        subtitle: createdAt == null ? null : Text(timeAgo(createdAt)),
        trailing: isRead
            ? null
            : Icon(
                Icons.circle,
                size: 10,
                color: colorScheme.primary,
              ),
      ),
    );
  }

  IconData _typeIcon() {
    switch (notification['type']) {
      case 'reply':
        return Icons.reply;
      case 'like':
        return Icons.favorite;
      case 'category_topic':
        return Icons.forum;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(ColorScheme colorScheme) {
    switch (notification['type']) {
      case 'reply':
        return colorScheme.primary;
      case 'like':
        return Colors.red;
      case 'category_topic':
        return Colors.green;
      default:
        return colorScheme.secondary;
    }
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              'Bienvenue sur ForumMada',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Accedez aux categories pour discuter avec la communaute malgache.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _categories = [];

  bool get _isAdmin {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = context.read<AuthProvider>().user?.id;
      final categories = await _apiService.getCategories(userId: userId);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCategoryFollow(Map<String, dynamic> category) async {
    final userId = context.read<AuthProvider>().user?.id;
    final categoryId = category['id'] as int?;
    if (userId == null || categoryId == null) return;

    final previous = category['is_following'] == true;
    setState(() {
      category['is_following'] = !previous;
    });

    try {
      final result = await _apiService.toggleCategoryFollow(
        categoryId: categoryId,
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        category['is_following'] = result['is_following'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        category['is_following'] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openCategoryForm({Map<String, dynamic>? category}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(category: category),
    );

    if (saved == true) {
      await _loadCategories();
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la categorie'),
          content: Text(
            'Supprimer "${category["name"]}" ? Les sujets rattaches ne seront plus classes dans cette categorie.',
          ),
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

    try {
      final role = context.read<AuthProvider>().user?.role ?? 'user';
      await _apiService.deleteCategory(
        id: category['id'] as int,
        role: role,
      );
      await _loadCategories();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categorie supprimee')),
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
              onPressed: _loadCategories,
              child: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    final isAdmin = _isAdmin;

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAdmin) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openCategoryForm(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une categorie'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final item in _categories)
            _buildCategoryCard(
              item as Map<String, dynamic>,
              isAdmin: isAdmin,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    Map<String, dynamic> category, {
    required bool isAdmin,
  }) {
    final color = _parseColor(category['color'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha((0.2 * 255).round()),
          child: Icon(
            _getIconData(category['icon'] as String?),
            color: color,
          ),
        ),
        title: Text(category['name'] as String? ?? ''),
        subtitle: Text(category['description'] as String? ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: category['is_following'] == true
                  ? 'Ne plus suivre'
                  : 'Suivre',
              icon: Icon(
                category['is_following'] == true
                    ? Icons.notifications_active
                    : Icons.notifications_none,
              ),
              onPressed: () => _toggleCategoryFollow(category),
            ),
            if (isAdmin)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openCategoryForm(category: category);
                  } else if (value == 'delete') {
                    _deleteCategory(category);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Modifier'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Supprimer'),
                    ),
                  ),
                ],
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicsScreen(
                categoryId: category['id'] as int,
                categoryName: category['name'] as String? ?? 'Sujets',
              ),
            ),
          );
        },
      ),
    );
  }

  Color _parseColor(String? value) {
    if (value == null || value.length < 7) {
      return Colors.blue;
    }
    return Color(int.parse(value.substring(1, 7), radix: 16) + 0xFF000000);
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'chat':
        return Icons.chat;
      case 'computer':
        return Icons.computer;
      case 'palette':
        return Icons.palette;
      case 'calendar':
        return Icons.calendar_today;
      case 'newspaper':
        return Icons.newspaper;
      case 'cart':
        return Icons.shopping_cart;
      default:
        return Icons.forum;
    }
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final Map<String, dynamic>? category;

  const _CategoryFormDialog({this.category});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _slugController;
  String _selectedIcon = 'chat';
  String _selectedColor = '#6C63FF';
  bool _isSaving = false;

  static const _icons = <String, IconData>{
    'chat': Icons.chat,
    'computer': Icons.computer,
    'palette': Icons.palette,
    'calendar': Icons.calendar_today,
    'newspaper': Icons.newspaper,
    'cart': Icons.shopping_cart,
    'forum': Icons.forum,
    'school': Icons.school,
  };

  static const _colors = <String>[
    '#FF6B6B',
    '#4ECDC4',
    '#45B7D1',
    '#96CEB4',
    '#FFEAA7',
    '#DDA0DD',
    '#6C63FF',
    '#FF9F43',
  ];

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(
      text: category?['name'] as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: category?['description'] as String? ?? '',
    );
    _slugController = TextEditingController(
      text: category?['slug'] as String? ?? '',
    );
    _selectedIcon = category?['icon'] as String? ?? 'chat';
    _selectedColor = category?['color'] as String? ?? '#6C63FF';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final role = context.read<AuthProvider>().user?.role ?? 'user';
      if (_isEditing) {
        await _apiService.updateCategory(
          id: widget.category!['id'] as int,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          slug: _slugController.text.trim(),
          role: role,
        );
      } else {
        await _apiService.createCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          icon: _selectedIcon,
          color: _selectedColor,
          slug: _slugController.text.trim(),
          role: role,
        );
      }

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

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Color _parseColor(String value) {
    return Color(int.parse(value.substring(1, 7), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier la categorie' : 'Ajouter une categorie'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  if (!_isEditing) {
                    _slugController.text = _slugify(value);
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nom requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugController,
                decoration: const InputDecoration(labelText: 'Slug'),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Slug requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _icons.containsKey(_selectedIcon) ? _selectedIcon : 'forum',
                decoration: const InputDecoration(labelText: 'Icone'),
                items: _icons.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(entry.value),
                            const SizedBox(width: 8),
                            Text(entry.key),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedIcon = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in _colors)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _selectedColor = color),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _parseColor(color),
                          child: _selectedColor == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
