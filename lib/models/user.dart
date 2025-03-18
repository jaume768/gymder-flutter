// lib/models/user.dart

class ProfilePicture {
  final String url;
  final String publicId;

  ProfilePicture({required this.url, required this.publicId});

  factory ProfilePicture.fromJson(Map<String, dynamic> json) {
    return ProfilePicture(
      url: json['url'] ?? '',
      publicId: json['public_id'] ?? '',
    );
  }
}

class Photo {
  final String id;
  final String url;
  final String publicId;

  Photo({required this.id, required this.url, required this.publicId});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['_id'],
      url: json['url'],
      publicId: json['public_id'],
    );
  }
}

class LocationData {
  final String type;
  final List<double> coordinates;

  LocationData({required this.type, required this.coordinates});

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      type: json['type'] ?? '',
      coordinates: (json['coordinates'] != null)
          ? List<double>.from(json['coordinates'].map((x) => x.toDouble()))
          : [],
    );
  }
}


class User {
  final String id;
  final String email;
  final String username;
  final bool isPremium;
  final DateTime? premiumExpiration;
  final String? goal;
  final ProfilePicture? profilePicture;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final List<String>? seeking;
  final String? relationshipGoal;
  final List<String>? likes;
  final List<String>? matches;
  final List<String>? blockedUsers;
  final List<Photo>? photos;
  final String? googleId;
  final LocationData? location;
  final String? biography;
  final String? city;
  final String? country;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.isPremium,
    this.premiumExpiration,
    this.goal,
    this.profilePicture,
    this.firstName,
    this.lastName,
    this.gender,
    this.biography,
    this.seeking,
    this.relationshipGoal,
    this.likes,
    this.matches,
    this.blockedUsers,
    this.photos,
    this.googleId,
    this.location,
    this.city,
    this.country,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Print debugging info for profile picture
    print('User.fromJson: ${json['username']}');
    if (json['profilePicture'] != null) {
      print('Profile picture data: ${json['profilePicture']}');
    } else {
      print('Profile picture is null for user: ${json['username']}');
    }
    
    return User(
      id: json['id'] ?? json['_id'],
      email: json['email'],
      username: json['username'],
      isPremium: json['isPremium'] ?? false,
      premiumExpiration: json['premiumExpiration'] != null
          ? DateTime.parse(json['premiumExpiration'])
          : null,
      goal: json['goal'],
      profilePicture: json['profilePicture'] != null
          ? ProfilePicture.fromJson(json['profilePicture'])
          : null,
      firstName: json['firstName'],
      lastName: json['lastName'],
      gender: json['gender'],
      seeking: json['seeking'] != null ? List<String>.from(json['seeking']) : [],
      relationshipGoal: json['relationshipGoal'],
      likes: json['likes'] != null ? List<String>.from(json['likes']) : [],
      matches: json['matches'] != null ? List<String>.from(json['matches']) : [],
      blockedUsers: json['blockedUsers'] != null ? List<String>.from(json['blockedUsers']) : [],
      photos: json['photos'] != null
          ? List<Photo>.from(json['photos'].map((x) => Photo.fromJson(x)))
          : [],
      googleId: json['googleId'],
      biography: json['biography'],
      location: json['location'] != null
          ? LocationData.fromJson(json['location'])
          : null,
      city: json['city'],
      country: json['country'],
    );
  }
}
