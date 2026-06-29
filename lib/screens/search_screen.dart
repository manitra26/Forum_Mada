import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import '../widgets/topic_card.dart';
import 'topic_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _queryController = TextEditingController();
  List<dynamic> _categories = [];
  List<Topic> _topics = [];
  List<Map<String, dynamic>> _posts = [];
  int? _categoryId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _type = 'all';
  bool _onlyMine = false;
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final userId = context.read<AuthProvider>().user?.id;
      final categories = await _apiService.getCategories(userId: userId);
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      // Filters remain usable without categories.
    }
  }

  Future<void> _runSearch() async {
    final user = context.read<AuthProvider>().user;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final result = await _apiService.search(
        query: _queryController.text,
        categoryId: _categoryId,
        userId: _onlyMine ? user?.id : null,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        type: _type,
      );
      if (!mounted) return;
      setState(() {
        _topics = (result['topics'] as List<dynamic>? ?? const [])
            .map((item) => Topic.fromJson(item as Map<String, dynamic>))
            .toList();
        _posts = (result['posts'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
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

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? _dateFrom : _dateTo;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = selected;
      } else {
        _dateTo = selected;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _categoryId = null;
      _dateFrom = null;
      _dateTo = null;
      _type = 'all';
      _onlyMine = false;
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _topics.length + _posts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Titre, contenu, utilisateur...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _runSearch(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Categorie',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Toutes les categories'),
                ),
                for (final item in _categories)
                  DropdownMenuItem<int?>(
                    value: (item as Map<String, dynamic>)['id'] as int,
                    child: Text(item['name']?.toString() ?? ''),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'all',
                  icon: Icon(Icons.manage_search),
                  label: Text('Tout'),
                ),
                ButtonSegment(
                  value: 'topics',
                  icon: Icon(Icons.forum),
                  label: Text('Sujets'),
                ),
                ButtonSegment(
                  value: 'posts',
                  icon: Icon(Icons.reply),
                  label: Text('Reponses'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.person, size: 18),
                  label: const Text('Mes contenus'),
                  selected: _onlyMine,
                  onSelected: (value) => setState(() => _onlyMine = value),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(
                    _dateFrom == null
                        ? 'Date debut'
                        : 'Depuis ${_formatDate(_dateFrom)}',
                  ),
                  onPressed: () => _pickDate(isFrom: true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_available, size: 18),
                  label: Text(
                    _dateTo == null
                        ? 'Date fin'
                        : 'Jusqu au ${_formatDate(_dateTo)}',
                  ),
                  onPressed: () => _pickDate(isFrom: false),
                ),
                ActionChip(
                  avatar: const Icon(Icons.filter_alt_off, size: 18),
                  label: const Text('Reset filtres'),
                  onPressed: _clearFilters,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _runSearch,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Rechercher'),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              _SearchMessage(
                icon: Icons.error,
                text: _error!,
              )
            else if (!_hasSearched)
              const _SearchMessage(
                icon: Icons.search,
                text: 'Lancez une recherche pour trouver des discussions.',
              )
            else if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (total == 0)
              const _SearchMessage(
                icon: Icons.search_off,
                text: 'Aucun resultat trouve.',
              )
            else ...[
              Text(
                '$total resultat${total > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final topic in _topics)
                TopicCard(
                  topic: topic,
                  onChanged: _runSearch,
                ),
              for (final post in _posts)
                _PostSearchResult(
                  post: post,
                  onChanged: _runSearch,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SearchMessage({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PostSearchResult extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onChanged;

  const _PostSearchResult({
    required this.post,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final topicJson = post['topic'];
    if (topicJson is! Map) {
      return const SizedBox.shrink();
    }

    final topic = Topic.fromJson(Map<String, dynamic>.from(topicJson));
    final createdAt = DateTime.tryParse(post['created_at']?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.reply),
        ),
        title: Text(post['content']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Dans: ${topic.title}'),
            const SizedBox(height: 4),
            Text(
              [
                post['username']?.toString() ?? '',
                if (createdAt != null) timeAgo(createdAt),
              ].where((item) => item.isNotEmpty).join(' - '),
            ),
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
            onChanged();
          }
        },
      ),
    );
  }
}
