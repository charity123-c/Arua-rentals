class AppUser {
  String id;
  String name;
  String email; // phone or email
  String role; // 'admin', 'provider', 'user'
  String phone;
  String bio;
  String profileImage;
  bool isApproved;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.bio = '',
    this.profileImage = '',
    this.isApproved = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'bio': bio,
  };

  factory AppUser.fromJson(Map json) => AppUser(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    role: json['role'],
    phone: json['phone'] ?? '',
    bio: json['bio'] ?? '',
  );
}
