class Profile {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String bio;
 
  final String? profileImageBase64;

   final String ? googleBusiness;
  final String ?instagram;
  final String ?linkedin;
  final String ?facebook;

  Profile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.bio,
   
    this.profileImageBase64,
    this.googleBusiness,

    this.instagram,

    this.linkedin,
    this.facebook,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    // Debug: Print all keys in JSON response
    print('DEBUG: JSON keys in response: ${json.keys.toList()}');
    print('DEBUG: Full JSON response: $json');
    
    return Profile(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      bio: json['bio'] ?? '',
      googleBusiness: json['googleBusiness'] ?? '',
      instagram: json['instagram'] ?? '',
      linkedin: json['linkedin'] ?? '',
      facebook: json['facebook'] ?? '',
      profileImageBase64: json['profileImageBase64'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'bio': bio,
      'googleBusiness':googleBusiness,
      'instagram':instagram,
      'linkedin':linkedin,
      'facebook':facebook,
      'profileImageBase64': profileImageBase64,
    };
  }
}

