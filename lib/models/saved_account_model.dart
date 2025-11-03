class SavedAccountModel {
  final String uid;
  final String email;
  final String? companyName; // 회사명/조직명
  final String? profileImageUrl;
  final DateTime lastLoginAt;
  final bool isCurrentAccount;

  SavedAccountModel({
    required this.uid,
    required this.email,
    this.companyName,
    this.profileImageUrl,
    required this.lastLoginAt,
    this.isCurrentAccount = false,
  });

  factory SavedAccountModel.fromMap(Map<String, dynamic> map) {
    return SavedAccountModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      companyName: map['companyName'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      lastLoginAt: DateTime.parse(map['lastLoginAt'] as String),
      isCurrentAccount: map['isCurrentAccount'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'companyName': companyName,
      'profileImageUrl': profileImageUrl,
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isCurrentAccount': isCurrentAccount,
    };
  }

  SavedAccountModel copyWith({
    String? uid,
    String? email,
    String? companyName,
    String? profileImageUrl,
    DateTime? lastLoginAt,
    bool? isCurrentAccount,
  }) {
    return SavedAccountModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      companyName: companyName ?? this.companyName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isCurrentAccount: isCurrentAccount ?? this.isCurrentAccount,
    );
  }

  // 표시용 이름 (조직명 우선, 없으면 이메일)
  String get displayName => companyName?.isNotEmpty == true ? companyName! : email;
}
