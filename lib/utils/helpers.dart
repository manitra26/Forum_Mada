import 'package:flutter/material.dart';

bool isValidEmail(String? email) {
  if (email == null) return false;
  final regex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
  return regex.hasMatch(email);
}

String formatAvatarText(String text) {
  if (text.isEmpty) return '?';
  return text.trim().substring(0, 1).toUpperCase();
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}
