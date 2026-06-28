import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final role = context.read<AuthProvider>().user?.role ?? 'user';
      final stats = await _apiService.getAdminStats(role: role);
      if (!mounted) return;
      setState(() {
        _stats = stats;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard admin')),
      body: _buildBody(),
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
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats ?? <String, dynamic>{};
    final totals = stats['totals'] as Map<String, dynamic>? ?? {};
    final popularTopics =
        stats['popular_topics'] as List<dynamic>? ?? const [];
    final dailyActivity =
        stats['daily_activity'] as List<dynamic>? ?? const [];

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              _StatCard(
                icon: Icons.people,
                label: 'Utilisateurs',
                value: '${totals['users'] ?? 0}',
                color: Colors.indigo,
              ),
              _StatCard(
                icon: Icons.topic,
                label: 'Sujets',
                value: '${totals['topics'] ?? 0}',
                color: Colors.deepPurple,
              ),
              _StatCard(
                icon: Icons.forum,
                label: 'Messages',
                value: '${totals['posts'] ?? 0}',
                color: Colors.teal,
              ),
              _StatCard(
                icon: Icons.local_fire_department,
                label: 'Top sujets',
                value: '${popularTopics.length}',
                color: Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.local_fire_department,
            title: 'Sujets populaires',
          ),
          const SizedBox(height: 8),
          if (popularTopics.isEmpty)
            const _EmptyPanel(text: 'Aucun sujet populaire pour le moment')
          else
            for (var i = 0; i < popularTopics.length; i++)
              _PopularTopicTile(
                rank: i + 1,
                topic: popularTopics[i] as Map<String, dynamic>,
              ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.bar_chart,
            title: 'Activite quotidienne',
          ),
          const SizedBox(height: 8),
          if (dailyActivity.isEmpty)
            const _EmptyPanel(text: 'Aucune activite recente')
          else
            for (final activity in dailyActivity)
              _ActivityTile(activity: activity as Map<String, dynamic>),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(36),
              child: Icon(icon, color: color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PopularTopicTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> topic;

  const _PopularTopicTile({
    required this.rank,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('$rank')),
        title: Text(topic['title'] as String? ?? 'Sujet'),
        subtitle: Text('${topic['posts_count'] ?? 0} reponses'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, size: 18),
            const SizedBox(width: 4),
            Text('${topic['views'] ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(activity['date'] as String? ?? '');
    final label = date == null
        ? 'Date inconnue'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      child: ListTile(
        leading: Container(
          width: 92,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withAlpha(32),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text('${activity['topics_count'] ?? 0} nouveaux sujets'),
        subtitle: Text('${activity['posts_count'] ?? 0} nouveaux messages'),
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
