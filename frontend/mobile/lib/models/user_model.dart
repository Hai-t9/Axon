class UserModel {
  final String id;
  final String email;
  final String? fullname;
  final String? phone;

  const UserModel({
    required this.id,
    required this.email,
    this.fullname,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullname: json['fullname'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
