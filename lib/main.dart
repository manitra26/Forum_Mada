import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/create_topic_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/topic_detail_screen.dart';
import 'screens/topics_screen.dart';
import 'models/topic.dart';

void main() {
  runApp(const ForumMadaApp());
}

class ForumMadaApp extends StatelessWidget {
  const ForumMadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ForumMada',
            theme: themeProvider.themeData,
            debugShowCheckedModeBanner: false,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const HomeScreen(),
              '/topics': (_) => const TopicsScreen(),
              '/create-topic': (_) => const CreateTopicScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/topic-detail') {
                final topic = settings.arguments as Topic?;
                return MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(
                      topic: topic ??
                          Topic(
                            id: 0,
                            title: 'Sujet inconnu',
                            content: 'Aucun détail disponible.',
                            userId: 0,
                            username: 'Anonyme',
                            avatarUrl: null,
                            categoryId: 0,
                            categoryName: 'Général',
                            views: 0,
                            isPinned: false,
                            isLocked: false,
                            postsCount: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          )),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
