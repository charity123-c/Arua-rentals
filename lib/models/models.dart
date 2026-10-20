class Rental {
  final String id;
  final String title;
  final String location;
  final String type;
  final int price;
  final String description;
  final String imageUrl;
  final String contact;

  Rental({
    required this.id,
    required this.title,
    required this.location,
    required this.type,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.contact,
  });
}

class Fundi {
  final String id;
  final String name;
  final String skill;
  final String location;
  final double rating;
  final String description;
  final String imageUrl;
  final String contact;

  Fundi({
    required this.id,
    required this.name,
    required this.skill,
    required this.location,
    required this.rating,
    required this.description,
    required this.imageUrl,
    required this.contact,
  });
}
