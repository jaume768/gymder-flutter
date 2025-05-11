import 'package:meta/meta.dart';

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
      id: json['_id'] ?? '',
      url: json['url'] ?? '',
      publicId: json['public_id'] ?? '',
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
      coordinates: json['coordinates'] != null
          ? List<double>.from(
              json['coordinates'].map((x) => (x as num).toDouble()))
          : <double>[],
    );
  }
}

class User {
  final String id;
  final String? email;
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
  final int topLikeCount;
  final int? age;
  final int? height;
  final int? weight;
  final int? squatWeight;
  final int? benchPressWeight;
  final int? deadliftWeight;
  final int likeCount;
  final int scrollCount;
  final String? scrollLimitProfileId;
  final DateTime? scrollLimitReachedAt;
  final DateTime? likeLimitReachedAt;
  final String? promoCode;
  final String verificationStatus;
  final ProfilePicture? identityDocument;
  final ProfilePicture? selfieWithDocument;

  User({
    required this.id,
    this.email,
    required this.username,
    required this.isPremium,
    this.premiumExpiration,
    this.goal,
    this.profilePicture,
    this.firstName,
    this.lastName,
    this.gender,
    this.seeking,
    this.relationshipGoal,
    this.likes,
    this.matches,
    this.blockedUsers,
    this.photos,
    this.googleId,
    this.location,
    this.biography,
    this.city,
    this.country,
    required this.topLikeCount,
    this.age,
    this.height,
    this.weight,
    this.squatWeight,
    this.benchPressWeight,
    this.deadliftWeight,
    required this.likeCount,
    required this.scrollCount,
    this.scrollLimitProfileId,
    this.scrollLimitReachedAt,
    this.likeLimitReachedAt,
    this.promoCode,
    this.verificationStatus = 'false',
    this.identityDocument,
    this.selfieWithDocument,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] as String?,
      username: json['username'] ?? '',
      isPremium: json['isPremium'] ?? false,
      premiumExpiration: json['premiumExpiration'] != null
          ? DateTime.tryParse(json['premiumExpiration'])
          : null,
      goal: json['goal'] as String?,
      profilePicture: json['profilePicture'] != null
          ? ProfilePicture.fromJson(json['profilePicture'])
          : null,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      gender: json['gender'] as String?,
      seeking:
          json['seeking'] != null ? List<String>.from(json['seeking']) : null,
      relationshipGoal: json['relationshipGoal'] as String?,
      likes: json['likes'] != null ? List<String>.from(json['likes']) : null,
      matches:
          json['matches'] != null ? List<String>.from(json['matches']) : null,
      blockedUsers: json['blockedUsers'] != null
          ? List<String>.from(json['blockedUsers'])
          : null,
      photos: json['photos'] != null
          ? (json['photos'] as List).map((p) => Photo.fromJson(p)).toList()
          : null,
      googleId: json['googleId'] as String?,
      location: json['location'] != null
          ? LocationData.fromJson(json['location'])
          : null,
      biography: json['biography'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      topLikeCount: json['topLikeCount'] as int? ?? 0,
      age: json['age'] is int
          ? json['age']
          : (json['age'] != null ? int.tryParse(json['age'].toString()) : null),
      height: json['height'] is int
          ? json['height']
          : (json['height'] != null
              ? int.tryParse(json['height'].toString())
              : null),
      weight: json['weight'] is int
          ? json['weight']
          : (json['weight'] != null
              ? int.tryParse(json['weight'].toString())
              : null),
      squatWeight: json['squatWeight'] as int?,
      benchPressWeight: json['benchPressWeight'] as int?,
      deadliftWeight: json['deadliftWeight'] as int?,
      likeCount: json['likeCount'] as int? ?? 0,
      scrollCount: json['scrollCount'] as int? ?? 0,
      scrollLimitProfileId: json['scrollLimitProfileId'] as String?,
      scrollLimitReachedAt: json['scrollLimitReachedAt'] != null
          ? DateTime.tryParse(json['scrollLimitReachedAt'])
          : null,
      likeLimitReachedAt: json['likeLimitReachedAt'] != null
          ? DateTime.tryParse(json['likeLimitReachedAt'])
          : null,
      promoCode: json['promoCode'] as String?,
      verificationStatus: json['verificationStatus'] as String? ?? 'false',
      identityDocument: json['identityDocument'] != null
          ? ProfilePicture.fromJson(json['identityDocument'])
          : null,
      selfieWithDocument: json['selfieWithDocument'] != null
          ? ProfilePicture.fromJson(json['selfieWithDocument'])
          : null,
    );
  }
}
