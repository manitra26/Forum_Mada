import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../services/api_service.dart';
import '../widgets/topic_card.dart';
import 'create_topic_screen.dart';

class TopicsScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;

  const TopicsScreen({
    super.key,
    this.categoryId,
    this.categoryName,
  });

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Topic> _topics = [];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final topicsJson =
          await _apiService.getTopics(categoryId: widget.categoryId);
      setState(() {
        _topics = topicsJson
            .map((json) => Topic.fromJson(json as Map<String, dynamic>))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Sujets'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTopicScreen(categoryId: widget.categoryId),
            ),
          );
          if (created == true) {
            _loadTopics();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sujet cree avec succes')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Creer un sujet'),
      ),
    );
  }

  Widget _buildBody() {
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
              onPressed: _loadTopics,
              child: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    if (_topics.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTopics,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.forum_outlined, size: 72, color: Colors.grey),
            SizedBox(height: 16),
            Center(child: Text('Aucun sujet dans cette categorie')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTopics,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _topics.length,
        itemBuilder: (context, index) {
          return TopicCard(
            topic: _topics[index],
            onChanged: _loadTopics,
          );
        },
      ),
    );
  }
}
