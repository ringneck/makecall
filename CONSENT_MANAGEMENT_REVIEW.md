# 📋 개인정보보호법 준수 - 동의 관리 시스템 설계

## 🇰🇷 법적 요구사항

### 1. 개인정보보호법 (제22조, 제39조의3)
- ✅ **필수 동의**: 개인정보 수집·이용에 대한 동의
- ✅ **필수 동의**: 제3자 제공에 대한 동의 (해당 시)
- ✅ **동의 날짜 기록**: 동의 일시 명확히 기록
- ✅ **2년 주기 재동의**: 개인정보 유효기간 만료 시 재동의

### 2. 정보통신망법 (제22조)
- ✅ **이용약관 동의**: 서비스 이용약관 필수
- ✅ **개인정보처리방침 동의**: 개인정보 취급방침 필수
- ✅ **선택적 동의 분리**: 마케팅 수신 등 선택적 동의 별도 관리

---

## 📊 현재 시스템 분석

### **1. 현재 구현 상태** (signup_screen.dart)
```dart
bool _agreedToTerms = false;  // Line 30

// 동의 체크
if (!_agreedToTerms) {
  await DialogUtils.showWarning(
    context,
    '이용약관에 동의해주세요',
  );
  return;
}
```

**문제점:**
- ❌ 개인정보처리방침과 이용약관이 구분되지 않음
- ❌ 동의 날짜가 Firestore에 저장되지 않음
- ❌ 2년 주기 재동의 로직 없음
- ❌ 동의 철회 기능 없음
- ❌ 실제 약관 문서 링크 없음

### **2. Firestore 사용자 데이터 구조** (auth_service.dart Line 238-259)
```dart
final userData = {
  'uid': uid,
  'email': currentUser.email ?? '',
  'displayName': currentUser.displayName ?? 'User',
  'photoURL': currentUser.photoURL,
  'providers': providerIds,
  'createdAt': FieldValue.serverTimestamp(),
  'lastLoginAt': FieldValue.serverTimestamp(),
  // ... API 설정 필드들
};
```

**누락된 필드:**
- ❌ 개인정보처리방침 동의 여부
- ❌ 이용약관 동의 여부
- ❌ 동의 날짜
- ❌ 마지막 재동의 날짜
- ❌ 다음 재동의 예정일

### **3. UserModel 데이터 구조** (user_model.dart)
```dart
class UserModel {
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  // ... 다른 필드들
}
```

**누락된 필드:**
- ❌ 동의 관리 관련 필드 전무

---

## 🎯 필수 구현 사항

### **Phase 1: Firestore 스키마 확장** (코드 변경 없이 계획만)

#### **users 컬렉션에 추가할 필드:**
```dart
// 동의 관리 필드
'consentVersion': String,              // 약관 버전 (예: "1.0")
'termsAgreed': bool,                   // 이용약관 동의 여부
'termsAgreedAt': Timestamp,            // 이용약관 동의 날짜
'privacyPolicyAgreed': bool,           // 개인정보처리방침 동의 여부
'privacyPolicyAgreedAt': Timestamp,    // 개인정보처리방침 동의 날짜
'marketingConsent': bool,              // 마케팅 수신 동의 (선택)
'marketingConsentAt': Timestamp?,      // 마케팅 수신 동의 날짜
'lastConsentCheckAt': Timestamp,       // 마지막 동의 확인 날짜
'nextConsentCheckDue': Timestamp,      // 다음 재동의 예정일 (2년 후)
'consentHistory': [                    // 동의 이력 (Array)
  {
    'version': String,
    'agreedAt': Timestamp,
    'ipAddress': String,               // 동의 시 IP (선택)
    'type': String,                    // 'initial' | 'renewal' | 'update'
  }
]
```

#### **새 컬렉션: terms (약관 버전 관리)**
```dart
collection('terms').doc('current') {
  'version': '1.0',
  'termsUrl': 'https://makecallio.web.app/terms',
  'privacyPolicyUrl': 'https://makecallio.web.app/privacy',
  'effectiveDate': Timestamp,
  'minimumRequiredVersion': '1.0',
}
```

---

### **Phase 2: UserModel 확장**

```dart
class UserModel {
  // 기존 필드...
  
  // 🆕 동의 관리 필드
  final String? consentVersion;
  final bool termsAgreed;
  final DateTime? termsAgreedAt;
  final bool privacyPolicyAgreed;
  final DateTime? privacyPolicyAgreedAt;
  final bool? marketingConsent;
  final DateTime? marketingConsentAt;
  final DateTime? lastConsentCheckAt;
  final DateTime? nextConsentCheckDue;
  final List<ConsentRecord>? consentHistory;
  
  // 🆕 동의 만료 체크 메서드
  bool get needsConsentRenewal {
    if (nextConsentCheckDue == null) return true;
    return DateTime.now().isAfter(nextConsentCheckDue!);
  }
  
  // 🆕 동의 유효성 체크
  bool get hasValidConsent {
    return termsAgreed && 
           privacyPolicyAgreed && 
           !needsConsentRenewal;
  }
}

class ConsentRecord {
  final String version;
  final DateTime agreedAt;
  final String? ipAddress;
  final String type; // 'initial' | 'renewal' | 'update'
}
```

---

### **Phase 3: 회원가입 화면 UI 개선**

#### **3.1 약관 동의 UI (signup_screen.dart)**
```dart
// 현재 (간단한 체크박스)
CheckboxListTile(
  title: const Text('이용약관에 동의합니다'),
  value: _agreedToTerms,
  onChanged: (value) {
    setState(() => _agreedToTerms = value ?? false);
  },
)

// 🆕 개선된 UI (필수/선택 분리)
Column(
  children: [
    // 전체 동의
    CheckboxListTile(
      title: Text('전체 동의', style: TextStyle(fontWeight: FontWeight.bold)),
      value: _allAgreed,
      onChanged: _handleAllAgree,
    ),
    Divider(),
    
    // 필수 동의 항목
    CheckboxListTile(
      title: Row(
        children: [
          Text('[필수] 이용약관 동의'),
          TextButton(
            child: Text('보기'),
            onPressed: () => _showTermsDialog(),
          ),
        ],
      ),
      value: _termsAgreed,
      onChanged: (value) => setState(() => _termsAgreed = value ?? false),
    ),
    
    CheckboxListTile(
      title: Row(
        children: [
          Text('[필수] 개인정보처리방침 동의'),
          TextButton(
            child: Text('보기'),
            onPressed: () => _showPrivacyPolicyDialog(),
          ),
        ],
      ),
      value: _privacyPolicyAgreed,
      onChanged: (value) => setState(() => _privacyPolicyAgreed = value ?? false),
    ),
    
    // 선택적 동의 항목
    CheckboxListTile(
      title: Text('[선택] 마케팅 정보 수신 동의'),
      value: _marketingConsent,
      onChanged: (value) => setState(() => _marketingConsent = value ?? false),
    ),
  ],
)
```

---

### **Phase 4: 동의 저장 로직**

#### **4.1 회원가입 시 동의 저장 (auth_service.dart)**
```dart
Future<void> signUp({
  required String email,
  required String password,
  required ConsentData consentData,  // 🆕 동의 데이터
}) async {
  final userCredential = await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  final now = Timestamp.now();
  final twoYearsLater = DateTime.now().add(Duration(days: 730));
  
  await _firestore.collection('users').doc(userCredential.user!.uid).set({
    // 기존 필드들...
    
    // 🆕 동의 필드
    'consentVersion': consentData.version,
    'termsAgreed': consentData.termsAgreed,
    'termsAgreedAt': now,
    'privacyPolicyAgreed': consentData.privacyPolicyAgreed,
    'privacyPolicyAgreedAt': now,
    'marketingConsent': consentData.marketingConsent,
    'marketingConsentAt': consentData.marketingConsent ? now : null,
    'lastConsentCheckAt': now,
    'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
    'consentHistory': [
      {
        'version': consentData.version,
        'agreedAt': now,
        'type': 'initial',
      }
    ],
  });
}
```

#### **4.2 소셜 로그인 시 동의 저장**
```dart
// signup_screen.dart - _handleSocialLoginSuccess 메서드
await _updateFirestoreUserProfile(
  userId: result.userId!,
  // ... 기존 필드
  
  // 🆕 동의 필드 추가
  consentData: ConsentData(
    version: '1.0',
    termsAgreed: _termsAgreed,
    privacyPolicyAgreed: _privacyPolicyAgreed,
    marketingConsent: _marketingConsent,
  ),
);
```

---

### **Phase 5: 재동의 시스템**

#### **5.1 앱 시작 시 동의 만료 체크 (main.dart or auth_service.dart)**
```dart
Future<void> _checkConsentExpiration() async {
  final user = currentUserModel;
  if (user == null) return;
  
  if (user.needsConsentRenewal) {
    // 재동의 다이얼로그 표시
    await _showConsentRenewalDialog();
  }
}

Future<void> _showConsentRenewalDialog() async {
  final result = await showDialog<bool>(
    context: navigatorKey.currentContext!,
    barrierDismissible: false,  // 강제 동의
    builder: (context) => ConsentRenewalDialog(),
  );
  
  if (result == true) {
    await _renewConsent();
  } else {
    // 동의 거부 시 로그아웃
    await signOut();
  }
}
```

#### **5.2 재동의 저장**
```dart
Future<void> _renewConsent() async {
  final uid = currentUser?.uid;
  if (uid == null) return;
  
  final now = Timestamp.now();
  final twoYearsLater = DateTime.now().add(Duration(days: 730));
  
  await _firestore.collection('users').doc(uid).update({
    'lastConsentCheckAt': now,
    'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
    'consentHistory': FieldValue.arrayUnion([
      {
        'version': '1.0',  // 현재 약관 버전
        'agreedAt': now,
        'type': 'renewal',
      }
    ]),
  });
  
  // UserModel 재로드
  await _loadUserModel(uid);
}
```

---

### **Phase 6: 약관 문서 관리**

#### **6.1 Firebase Hosting에 약관 페이지 배포**
```
web/
├── terms.html              # 이용약관
├── privacy.html            # 개인정보처리방침
└── marketing-consent.html  # 마케팅 수신 동의 (선택)
```

#### **6.2 URL Launcher로 약관 표시**
```dart
Future<void> _showTermsDialog() async {
  final url = Uri.parse('https://makecallio.web.app/terms.html');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.inAppWebView);
  }
}
```

---

## 🔒 보안 및 감사 로그

### **Firestore Security Rules 추가**
```javascript
match /users/{userId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId;
  
  // 🆕 동의 필드는 생성 시에만 허용, 수정은 서버 측에서만
  allow update: if request.auth.uid == userId 
    && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['consentHistory']);
}
```

---

## 📅 구현 우선순위

### **High Priority (필수)**
1. ✅ UserModel에 동의 관리 필드 추가
2. ✅ 회원가입 UI에 필수/선택 동의 분리
3. ✅ 동의 날짜 Firestore 저장
4. ✅ 약관 문서 HTML 작성 및 배포
5. ✅ 소셜 로그인 동의 처리

### **Medium Priority (권장)**
6. ✅ 2년 주기 재동의 시스템
7. ✅ 동의 이력 관리
8. ✅ 앱 시작 시 동의 만료 체크

### **Low Priority (추가 기능)**
9. ⚪ 동의 철회 기능 (설정 화면)
10. ⚪ IP 주소 기록 (법적 증빙 강화)
11. ⚪ 약관 버전 관리 시스템

---

## 🚀 마이그레이션 전략

### **기존 사용자 처리**
```dart
// 첫 로그인 시 기존 사용자 동의 업데이트
Future<void> _migrateExistingUser(String uid) async {
  final doc = await _firestore.collection('users').doc(uid).get();
  final data = doc.data();
  
  // 동의 필드가 없는 기존 사용자
  if (data != null && data['termsAgreed'] == null) {
    await _showConsentDialog(isExistingUser: true);
  }
}
```

---

## 📊 체크리스트

### **법적 준수 체크리스트**
- [ ] 개인정보처리방침 문서 작성
- [ ] 이용약관 문서 작성
- [ ] 필수 동의와 선택 동의 UI 분리
- [ ] 동의 날짜 Firestore 저장
- [ ] 2년 주기 재동의 알림
- [ ] 동의 철회 기능
- [ ] 동의 이력 감사 로그

### **기술 구현 체크리스트**
- [ ] UserModel 확장
- [ ] Firestore 스키마 설계
- [ ] 회원가입 UI 개선
- [ ] 소셜 로그인 동의 처리
- [ ] 재동의 시스템 구현
- [ ] 약관 HTML 작성 및 배포
- [ ] Security Rules 업데이트
- [ ] 기존 사용자 마이그레이션

---

## 📝 참고 자료

- [개인정보보호법 전문](https://www.law.go.kr/법령/개인정보보호법)
- [정보통신망법 제22조](https://www.law.go.kr/법령/정보통신망이용촉진및정보보호등에관한법률)
- [개인정보보호위원회 가이드라인](https://www.pipc.go.kr/)

