class UserModel {
  final String id;
  final String email;
  final String? fullname;

  const UserModel({
    required this.id,
    required this.email,
    this.fullname,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullname: json['fullname'] as String?,
    );
  }
}
