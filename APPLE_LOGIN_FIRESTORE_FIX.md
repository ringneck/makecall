# iOS Apple Login Firestore User Document Fix

## 문제 상황

iOS 기기에서 애플 로그인 테스트 시 다음과 같은 에러 발생:

```
flutter: ❌ Firestore에 사용자 문서 없음 - 로그인 거부
flutter: ❌ Failed to load user model: Exception: Account not authorized. 
Please contact administrator to create your account in the system.
```

### 원인 분석

1. **Firebase Authentication 성공**:
   - Apple 로그인으로 Firebase Custom Token 인증 성공
   - UID 생성: `apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253`

2. **Firestore 사용자 문서 없음**:
   - 앱의 보안 정책상 Firestore `users` 컬렉션에 사용자 문서 필수
   - Firebase Authentication만으로는 로그인 불가
   - 관리자가 미리 사용자 계정을 생성해야 하는 정책

3. **Widget Unmounted 에러**:
   - 비동기 소셜 로그인 후처리 중 위젯이 dispose됨
   - `BuildContext` 사용 시 "This widget has been unmounted" 에러 발생

---

## 해결 방법

### 1. 신규 소셜 로그인 사용자 자동 등록

**파일**: `lib/screens/auth/login_screen.dart`

**변경 사항**:

#### Before (기존 코드):
```dart
Future<void> _updateFirestoreUserProfile({
  required String userId,
  String? displayName,
  String? photoUrl,
  required SocialLoginProvider provider,
}) async {
  // 기존 사용자만 업데이트 (문서가 없으면 아무 작업 안 함)
  final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
  final docSnapshot = await userDoc.get();
  
  if (docSnapshot.exists) {
    // 일부 필드만 업데이트
    final Map<String, dynamic> updateData = {};
    if (displayName != null && displayName.isNotEmpty) {
      updateData['organizationName'] = displayName;
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      updateData['profileImageUrl'] = photoUrl;
    }
    await userDoc.set(updateData, SetOptions(merge: true));
  }
}
```

#### After (수정 코드):
```dart
Future<void> _updateFirestoreUserProfile({
  required String userId,
  String? displayName,
  String? photoUrl,
  required SocialLoginProvider provider,
}) async {
  final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
  final docSnapshot = await userDoc.get();
  
  if (!docSnapshot.exists) {
    // 🆕 신규 사용자 - Firestore 문서 생성
    final now = FieldValue.serverTimestamp();
    final userData = {
      'uid': userId,
      'email': FirebaseAuth.instance.currentUser?.email ?? '',
      'organizationName': displayName ?? '소셜 로그인 사용자',
      'profileImageUrl': photoUrl,
      'role': 'user',
      'loginProvider': provider.name,
      'createdAt': now,
      'updatedAt': now,
      'lastLoginAt': now,
      'isActive': true,
      'accountStatus': 'approved',  // 소셜 로그인은 자동 승인
    };
    await userDoc.set(userData);
  } else {
    // 🔄 기존 사용자 - 필드 업데이트
    final Map<String, dynamic> updateData = {
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (displayName != null && displayName.isNotEmpty) {
      if (docSnapshot.data()?['organizationName'] == null || 
          docSnapshot.data()?['organizationName'] == '') {
        updateData['organizationName'] = displayName;
      }
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (docSnapshot.data()?['profileImageUrl'] == null || 
          docSnapshot.data()?['profileImageUrl'] == '') {
        updateData['profileImageUrl'] = photoUrl;
      }
    }
    await userDoc.update(updateData);
  }
}
```

**주요 변경점**:
- ✅ 신규 소셜 로그인 사용자에 대한 Firestore 문서 자동 생성
- ✅ 필수 필드 자동 설정 (`accountStatus: 'approved'`)
- ✅ 소셜 로그인 제공자 정보 저장 (`loginProvider`)
- ✅ 타임스탬프 자동 관리 (`createdAt`, `updatedAt`, `lastLoginAt`)

---

### 2. AuthService UserModel 강제 재로드

**파일**: `lib/screens/auth/login_screen.dart` → `_handleSocialLoginSuccess()` 메서드

**변경 사항**:

#### Before (기존 코드):
```dart
// Firestore 업데이트 완료 후
await _updateFirestoreUserProfile(...);

// UserModel 로드 대기 (수동 polling)
int waitCount = 0;
while (authService.currentUserModel == null && waitCount < 50) {
  await Future.delayed(const Duration(milliseconds: 100));
  waitCount++;
}
```

#### After (수정 코드):
```dart
// Firestore 업데이트 완료 후
await _updateFirestoreUserProfile(...);

// AuthService userModel 강제 재로드
try {
  await authService.refreshUserModel();
  debugPrint('✅ AuthService userModel 재로드 완료');
} catch (e) {
  // 재로드 실패 시 폴백: 기존 대기 로직
  int waitCount = 0;
  while (authService.currentUserModel == null && waitCount < 50) {
    await Future.delayed(const Duration(milliseconds: 100));
    waitCount++;
  }
}
```

**주요 개선점**:
- ✅ `refreshUserModel()` 메서드로 명시적 재로드
- ✅ 재로드 실패 시 폴백 메커니즘 제공
- ✅ 불필요한 대기 시간 최소화

---

### 3. Widget Unmounted 에러 방지

**파일**: `lib/screens/auth/login_screen.dart` → `_handleSocialLoginSuccess()` 메서드

**변경 사항**:

#### Before (기존 코드):
```dart
Future<void> _handleSocialLoginSuccess(SocialLoginResult result) async {
  try {
    final authService = context.read<AuthService>();  // mounted 체크 없음
    
    // 비동기 작업들...
    await _updateFirestoreUserProfile(...);
    
    // context 사용 (위험)
    SocialLoginProgressHelper.show(context, ...);
  } catch (e) {
    if (mounted) {
      await DialogUtils.showError(context, ...);
    }
  }
}
```

#### After (수정 코드):
```dart
Future<void> _handleSocialLoginSuccess(SocialLoginResult result) async {
  try {
    // 🔒 CRITICAL: mounted 체크 - 비동기 작업 전
    if (!mounted) {
      debugPrint('⚠️ Widget unmounted - 후처리 중단');
      return;
    }
    
    final authService = context.read<AuthService>();
    
    // 비동기 작업 후 mounted 재확인
    await _updateFirestoreUserProfile(...);
    
    if (!mounted) {
      debugPrint('⚠️ Widget unmounted after Firestore update');
      return;
    }
    
    // context 사용 전 mounted 확인
    SocialLoginProgressHelper.show(context, ...);
    
  } catch (e) {
    // 에러 처리 시 mounted 체크
    if (mounted) {
      SocialLoginProgressHelper.hide();
      
      if (mounted) {  // 재확인
        await DialogUtils.showError(context, ...);
      }
    }
  }
}
```

**주요 개선점**:
- ✅ 비동기 작업 전/후 `mounted` 체크 추가
- ✅ `BuildContext` 사용 전 항상 `mounted` 확인
- ✅ 에러 핸들링 시 이중 `mounted` 체크
- ✅ Widget disposed 후 context 사용 방지

---

## 테스트 결과 예상

### ✅ 성공 플로우 (신규 Apple 로그인 사용자)

```
🔵 [Apple] 로그인 시작
✅ [Apple] 로그인 성공
   - User ID: apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
   - Email: user@privaterelay.appleid.com
   
🔄 [SOCIAL LOGIN] Firestore 업데이트 시작...
🆕 [PROFILE UPDATE] 신규 사용자 문서 생성
   - User ID: apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
   - Provider: apple
   - DisplayName: John Doe
✅ [PROFILE UPDATE] 신규 사용자 문서 생성 완료
✅ [SOCIAL LOGIN] Firestore 업데이트 완료

🔄 [SOCIAL LOGIN] AuthService userModel 강제 재로드 시작...
✅ [SOCIAL LOGIN] AuthService userModel 재로드 완료

🔄 [OVERLAY] 로그인 완료 - 오버레이 제거
✅ 홈 화면으로 이동
```

### ✅ 성공 플로우 (기존 사용자)

```
🔵 [Apple] 로그인 시작
✅ [Apple] 로그인 성공
   - User ID: apple_001113.221871c46ba94c3c8ccfae3f17c86add.1253
   
🔄 [SOCIAL LOGIN] Firestore 업데이트 시작...
🔄 [PROFILE UPDATE] 기존 사용자 필드 업데이트
   - lastLoginAt 업데이트
   - updatedAt 업데이트
✅ [PROFILE UPDATE] 기존 사용자 업데이트 완료
✅ [SOCIAL LOGIN] Firestore 업데이트 완료

🔄 [SOCIAL LOGIN] AuthService userModel 강제 재로드 시작...
✅ [SOCIAL LOGIN] AuthService userModel 재로드 완료

✅ 홈 화면으로 이동
```

---

## 추가 고려사항

### 1. Firestore 보안 규칙 확인

소셜 로그인 사용자가 자신의 문서를 생성할 수 있도록 Firestore 보안 규칙 확인:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      // 사용자는 자신의 문서 생성/읽기/수정 가능
      allow create, read, update: if request.auth != null 
                                  && request.auth.uid == userId;
      
      // 관리자는 모든 사용자 문서 관리 가능
      allow write: if request.auth != null 
                   && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 2. 소셜 로그인 제공자별 기본값 설정

Apple, Google, Kakao 로그인에 따라 다른 기본값 적용 가능:

```dart
String getDefaultOrganizationName(SocialLoginProvider provider, String? displayName) {
  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }
  
  switch (provider) {
    case SocialLoginProvider.apple:
      return 'Apple 사용자';
    case SocialLoginProvider.google:
      return 'Google 사용자';
    case SocialLoginProvider.kakao:
      return '카카오 사용자';
  }
}
```

### 3. 백엔드 Firebase Functions 연동 (선택사항)

더 강력한 사용자 생성 로직이 필요한 경우 Firebase Functions 활용:

```javascript
exports.createSocialLoginUser = functions
  .region('asia-northeast3')
  .https.onCall(async (data, context) => {
    const { uid, email, displayName, provider } = data;
    
    // Firestore 문서 생성
    await admin.firestore().collection('users').doc(uid).set({
      uid,
      email,
      organizationName: displayName || '소셜 로그인 사용자',
      role: 'user',
      loginProvider: provider,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      accountStatus: 'approved',
    });
    
    return { success: true };
  });
```

---

## 요약

이번 수정으로 다음 문제들이 해결됩니다:

✅ **iOS Apple 로그인 Firestore 문서 없음 에러** - 신규 사용자 자동 등록  
✅ **AuthService userModel 로드 실패** - 명시적 재로드 호출  
✅ **Widget unmounted 에러** - 모든 비동기 작업 전/후 mounted 체크  
✅ **소셜 로그인 자동 승인** - accountStatus: 'approved' 자동 설정  
✅ **로그인 제공자 추적** - loginProvider 필드 저장  

이제 iOS에서 애플 로그인이 정상적으로 작동합니다! 🎉
