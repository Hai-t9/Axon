class ProfileData {
  final String? id;
  final String email;
  final String? fullname;
  final String? createdAt;

  const ProfileData({
    this.id,
    required this.email,
    this.fullname,
    this.createdAt,
  });

  factory ProfileData.fromAuthSession(Map<String, dynamic> userJson) {
    return ProfileData(
      id: userJson['id']?.toString(),
      email: userJson['email'] as String? ?? '',
      fullname: userJson['fullname'] as String?,
      createdAt: userJson['created_at'] as String?,
    );
  }
}
