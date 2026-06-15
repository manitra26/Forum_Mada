bool isValidEmail(String? email) {
  if (email == null) return false;
  final pattern = r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}";
  return RegExp(pattern).hasMatch(email);
}

bool isNotEmpty(String? value) => value != null && value.trim().isNotEmpty;
