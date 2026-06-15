import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryCard extends StatelessWidget {
  final Category category;

  const CategoryCard({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(category.name.substring(0, 1).toUpperCase()),
        ),
        title: Text(category.name),
        subtitle: Text(category.description),
        trailing: Text('${category.topicsCount} sujets'),
      ),
    );
  }
}
