class SavedAccountModel {
  final String uid;
  final String email;
  final String? organizationName; // 사용자 지정 조직명/닉네임
  final String? profileImageUrl;
  final DateTime lastLoginAt;
  final bool isCurrentAccount;

  SavedAccountModel({
    required this.uid,
    required this.email,
    this.organizationName,
    this.profileImageUrl,
    required this.lastLoginAt,
    this.isCurrentAccount = false,
  });

  factory SavedAccountModel.fromMap(Map<String, dynamic> map) {
    return SavedAccountModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      organizationName: map['organizationName'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      lastLoginAt: DateTime.parse(map['lastLoginAt'] as String),
      isCurrentAccount: map['isCurrentAccount'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'organizationName': organizationName,
      'profileImageUrl': profileImageUrl,
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isCurrentAccount': isCurrentAccount,
    };
  }

  SavedAccountModel copyWith({
    String? uid,
    String? email,
    String? organizationName,
    String? profileImageUrl,
    DateTime? lastLoginAt,
    bool? isCurrentAccount,
  }) {
    return SavedAccountModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      organizationName: organizationName ?? this.organizationName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isCurrentAccount: isCurrentAccount ?? this.isCurrentAccount,
    );
  }

  // 표시용 이름 (조직명 우선, 없으면 이메일)
  String get displayName => organizationName?.isNotEmpty == true ? organizationName! : email;
}
