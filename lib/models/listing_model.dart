class Listing {
  String id;
  String title;
  String location;
  String price;
  String providerId;
  String providerName;
  String imagePath;
  bool isApproved;

  Listing({
    required this.id,
    required this.title,
    required this.location,
    required this.price,
    required this.providerId,
    required this.providerName,
    this.imagePath = '',
    this.isApproved = false,
  });
}
