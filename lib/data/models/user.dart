class User {
  final int? id;
  final String? username;
  final String passwordHash;
  final bool isPasswordMd5;
  final String? externalId;
  final bool isActive;
  final int? gangId;

  User({
    this.id,
    this.username,
    this.passwordHash = '',
    this.isPasswordMd5 = false,
    this.externalId,
    this.isActive = true,
    this.gangId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'is_password_md5': isPasswordMd5 ? 1 : 0,
      'external_id': externalId,
      'is_active': isActive ? 1 : 0,
      'gang_id': gangId,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String?,
      passwordHash: map['password_hash'] as String? ?? '',
      isPasswordMd5: (map['is_password_md5'] as int?) == 1,
      externalId: map['external_id'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      gangId: map['gang_id'] as int?,
    );
  }
}