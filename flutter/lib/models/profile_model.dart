class ProfileModel {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String? gender;
  final DateTime? birthDate;
  final DateTime? joinedAt;

  const ProfileModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    this.gender,
    this.birthDate,
    this.joinedAt,
  });

  factory ProfileModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProfileModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      gender: json['gender']?.toString(),
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.tryParse(
              json['birth_date'].toString(),
            ),
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.tryParse(
              json['joined_at'].toString(),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photo_url': photoUrl,
      'gender': gender,
      'birth_date': birthDate?.toIso8601String(),
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? gender,
    DateTime? birthDate,
    DateTime? joinedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}