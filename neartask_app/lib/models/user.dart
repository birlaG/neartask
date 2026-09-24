class AppUser {
  final String id;
  final String phone;
  final String? email;
  final String name;
  final String role;
  final String kycStatus;
  final String verificationTier;
  final String profileVisibility;
  final double trustScore;
  final int completedTasks;
  final int noShowCount;

  AppUser({
    required this.id,
    required this.phone,
    this.email,
    required this.name,
    required this.role,
    required this.kycStatus,
    required this.verificationTier,
    required this.profileVisibility,
    required this.trustScore,
    required this.completedTasks,
    required this.noShowCount,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        phone: json['phone'],
        email: json['email'],
        name: json['name'],
        role: json['role'] ?? 'USER',
        kycStatus: json['kycStatus'] ?? 'UNVERIFIED',
        verificationTier: json['verificationTier'] ?? 'BASIC',
        profileVisibility: json['profileVisibility'] ?? 'FULL',
        trustScore: (json['trustScore'] ?? 0).toDouble(),
        completedTasks: json['completedTasks'] ?? 0,
        noShowCount: json['noShowCount'] ?? 0,
      );
}
