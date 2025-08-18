class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String userType; // 'rider' or 'driver'
  final DateTime createdAt;
  final String? profileImageUrl;
  final bool isActive;
  final Map<String, dynamic>? additionalInfo;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.userType,
    required this.createdAt,
    this.profileImageUrl,
    this.isActive = true,
    this.additionalInfo,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      return UserModel(
        id: json['id']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        userType: json['userType']?.toString() ?? 'rider',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'].toString())
            : DateTime.now(),
        profileImageUrl: json['profileImageUrl']?.toString(),
        isActive: json['isActive'] ?? true,
        additionalInfo: json['additionalInfo'] is Map<String, dynamic>
            ? json['additionalInfo']
            : null,
      );
    } catch (e) {
      print('Error parsing UserModel from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'userType': userType,
      'createdAt': createdAt.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'isActive': isActive,
      'additionalInfo': additionalInfo,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? userType,
    DateTime? createdAt,
    String? profileImageUrl,
    bool? isActive,
    Map<String, dynamic>? additionalInfo,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
}
