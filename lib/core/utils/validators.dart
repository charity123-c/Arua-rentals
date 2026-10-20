String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) return 'Enter a valid email address.';
  return null;
}

String? validatePassword(String? value) {
  if ((value ?? '').length < 8) return 'Password must be at least 8 characters.';
  return null;
}

String? validateName(String? value) {
  if ((value?.trim() ?? '').isEmpty) return 'Enter your name.';
  return null;
}
