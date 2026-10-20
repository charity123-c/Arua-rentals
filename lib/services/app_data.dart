import '../models/user_model.dart';
import '../models/listing_model.dart';

class AppData {
  static List<AppUser> users = [
    AppUser(
      id: '1',
      name: 'Charity (You)',
      email: 'charity@arua.com',
      role: 'admin',
      isApproved: true,
    ),
    AppUser(
      id: '2',
      name: 'Mama Atim',
      email: 'atim@gmail.com',
      role: 'provider',
      isApproved: true,
    ),
    AppUser(
      id: '3',
      name: 'Okello User',
      email: 'okello@gmail.com',
      role: 'user',
      isApproved: true,
    ),
  ];

  static List<Listing> listings = [
    Listing(
      id: '101',
      title: '3 Bedroom in Ediofe',
      location: 'Ediofe',
      price: '500k',
      providerId: '2',
      providerName: 'Mama Atim',
      isApproved: false,
    ),
  ];

  static AppUser currentUser =
      users[0]; // change this to test as different role
}
