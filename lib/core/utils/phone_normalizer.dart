String? normalizeUgandanPhone(String value) {
  final digits = value.replaceAll(RegExp(r'[\s()-]'), '');
  final national = switch (digits) {
    final value when RegExp(r'^0[2-9][0-9]{8}$').hasMatch(value) =>
      value.substring(1),
    final value when RegExp(r'^256[2-9][0-9]{8}$').hasMatch(value) =>
      value.substring(3),
    final value when RegExp(r'^\+256[2-9][0-9]{8}$').hasMatch(value) =>
      value.substring(4),
    _ => null,
  };
  return national == null ? null : '+256$national';
}
