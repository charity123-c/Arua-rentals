import '../models/models.dart';

class MockData {
  static final List<Rental> _rentals = [
    Rental(
      id: 'r1',
      title: 'Modern Self-Contained House',
      location: 'Mvara',
      type: 'Single Room',
      price: 150000,
      description: 'A clean, modern self-contained room with a private bathroom and kitchenette. Located in a quiet neighborhood in Mvara, close to the university.',
      imageUrl:
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
      contact: '256700111111',
    ),
    Rental(
      id: 'r2',
      title: 'Spacious 2-Bedroom Apartment',
      location: 'Awindiri',
      type: 'Apartment',
      price: 350000,
      description: 'Beautiful 2-bedroom apartment in Awindiri. Features a large living room, secure parking, and 24/7 water supply. Perfect for small families.',
      imageUrl:
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
      contact: '256700222222',
    ),
    Rental(
      id: 'r3',
      title: 'Executive Mansion',
      location: 'Ediofe',
      type: 'Whole House',
      price: 800000,
      description: "Luxury 3-bedroom mansion in Ediofe. Comes with a massive compound, boys' quarters, and high security. Ideal for expats or large families.",
      imageUrl:
          'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800',
      contact: '256700333333',
    ),
    Rental(
      id: 'r4',
      title: 'Cozy Bedsitter',
      location: 'Senior Quarters',
      type: 'Bedsitter',
      price: 100000,
      description: 'Affordable and clean bedsitter in Senior Quarters. Shared bathroom but very secure and close to the main road for easy transport.',
      imageUrl:
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
      contact: '256700444444',
    ),
  ];

  static final List<Fundi> _fundis = [
    Fundi(
      id: 'f1',
      name: 'John Drani',
      skill: 'Plumber',
      location: 'Arua City',
      rating: 4.8,
      description: 'Expert plumber with 10 years of experience. Specializes in pipe fitting, leak repairs, and bathroom installations. Available 24/7.',
      imageUrl:
          'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800',
      contact: '256791280345',
    ),
    Fundi(
      id: 'f2',
      name: 'Mary Candiru',
      skill: 'Electrician',
      location: 'Mvara',
      rating: 4.9,
      description: 'Certified electrician. Handles wiring, solar panel installation, and electrical fault finding. Safe and reliable service.',
      imageUrl:
          'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
      contact: '256700666666',
    ),
    Fundi(
      id: 'f3',
      name: 'Clean Sweep Services',
      skill: 'Cleaner',
      location: 'Awindiri',
      rating: 4.7,
      description: 'Professional home and office cleaning. We bring our own eco-friendly supplies. Deep cleaning, fumigation, and regular maintenance.',
      imageUrl:
          'https://images.unsplash.com/photo-1581578731568-4b08f4b8e2d6?w=800',
      contact: '256700777777',
    ),
    Fundi(
      id: 'f4',
      name: 'Swift Movers Arua',
      skill: 'Mover',
      location: 'Ediofe',
      rating: 4.6,
      description: 'Fast and safe house moving services within Arua City and beyond. We provide the truck and the labor. Careful with your furniture.',
      imageUrl:
          'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?w=800',
      contact: '256700888888',
    ),
  ];

  static List<Rental> get rentals => List.unmodifiable(_rentals);
  static List<Fundi> get fundis => List.unmodifiable(_fundis);

  static Rental? rentalById(String id) => _rentals.cast<Rental?>().firstWhere(
    (rental) => rental?.id == id,
    orElse: () => null,
  );

  static Fundi? fundiById(String id) => _fundis.cast<Fundi?>().firstWhere(
    (fundi) => fundi?.id == id,
    orElse: () => null,
  );
}
