# 소셜 로그인 백엔드 설정 가이드

이 문서는 카카오와 네이버 로그인을 위한 Firebase Custom Token 생성 백엔드를 설정하는 방법을 안내합니다.

---

## 📋 목차

1. [아키텍처 개요](#1-아키텍처-개요)
2. [Firebase Functions 설정](#2-firebase-functions-설정)
3. [카카오 Custom Token 엔드포인트](#3-카카오-custom-token-엔드포인트)
4. [네이버 Custom Token 엔드포인트](#4-네이버-custom-token-엔드포인트)
5. [보안 고려사항](#5-보안-고려사항)
6. [테스트 방법](#6-테스트-방법)

---

## 1. 아키텍처 개요

### 1.1 소셜 로그인 플로우 비교

**구글/애플 로그인 (Firebase 직접 통합)**:
```
Flutter App → Google/Apple SDK → Firebase Auth
         ↓
    자동 인증 완료
```

**카카오/네이버 로그인 (Custom Token 방식)**:
```
Flutter App → Kakao/Naver SDK → 사용자 정보 획득
         ↓
    Backend (Firebase Functions) → Custom Token 생성
         ↓
Flutter App → Firebase Auth.signInWithCustomToken()
```

### 1.2 왜 Custom Token이 필요한가?

- **구글/애플**: Firebase Authentication이 직접 지원 ✅
- **카카오/네이버**: Firebase가 직접 지원하지 않음 ❌
  - 대안: 카카오/네이버 SDK로 사용자 정보 획득 후
  - Firebase Custom Token으로 Firebase Authentication 통합

---

## 2. Firebase Functions 설정

### 2.1 Firebase CLI 설치

```bash
# Node.js 설치 확인 (v18 이상 권장)
node --version

# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# 프로젝트 초기화 (이미 functions/ 디렉토리가 있으면 스킵)
firebase init functions
```

### 2.2 필수 패키지 설치

```bash
cd functions

# Firebase Admin SDK 설치 (Custom Token 생성용)
npm install firebase-admin@latest

# Firebase Functions SDK
npm install firebase-functions@latest

# (선택) 추가 검증을 위한 패키지
npm install axios  # 카카오/네이버 API 검증용
```

### 2.3 환경 설정

**파일**: `functions/.env` (로컬 개발용)

```env
# Firebase 프로젝트 ID
FIREBASE_PROJECT_ID=your-project-id

# (선택) 카카오/네이버 API 검증용
KAKAO_ADMIN_KEY=your-kakao-admin-key
NAVER_API_KEY=your-naver-api-key
```

**Firebase Functions 환경 변수 설정**:

```bash
# 프로덕션 환경 변수 설정
firebase functions:config:set kakao.admin_key="YOUR_KAKAO_ADMIN_KEY"
firebase functions:config:set naver.api_key="YOUR_NAVER_API_KEY"

# 설정 확인
firebase functions:config:get
```

**⚠️ 참고**: Firebase Functions의 `functions.config()`는 2026년에 deprecated 예정이므로, 새로운 `.env` 방식 사용을 권장합니다.

---

## 3. 카카오 Custom Token 엔드포인트

### 3.1 함수 구현

**파일**: `functions/index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Firebase Admin SDK 초기화 (한 번만 실행)
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * 카카오 로그인용 Firebase Custom Token 생성
 * 
 * @param {object} data - 요청 데이터
 * @param {string} data.kakaoUid - 카카오 사용자 ID
 * @param {string} data.email - 카카오 계정 이메일
 * @param {string} data.displayName - 카카오 닉네임
 * @param {string} data.photoUrl - 카카오 프로필 이미지
 * @param {string} data.accessToken - 카카오 Access Token (검증용, 선택)
 * 
 * @returns {object} { customToken: string }
 */
exports.createCustomTokenForKakao = functions
  .region('asia-northeast3') // 서울 리전
  .https.onCall(async (data, context) => {
    try {
      // 입력 검증
      const { kakaoUid, email, displayName, photoUrl, accessToken } = data;
      
      if (!kakaoUid) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'kakaoUid is required'
        );
      }
      
      // (선택) 카카오 Access Token 검증
      // 프로덕션에서는 카카오 API를 호출하여 토큰 유효성 검증 권장
      // if (accessToken) {
      //   const axios = require('axios');
      //   const response = await axios.get('https://kapi.kakao.com/v2/user/me', {
      //     headers: { Authorization: `Bearer ${accessToken}` }
      //   });
      //   
      //   if (response.data.id !== parseInt(kakaoUid)) {
      //     throw new functions.https.HttpsError('permission-denied', 'Invalid token');
      //   }
      // }
      
      // Firebase UID 생성 (prefix로 구분)
      const firebaseUid = `kakao_${kakaoUid}`;
      
      console.log(`Creating custom token for Kakao user: ${firebaseUid}`);
      
      // Custom Token 생성
      const customToken = await admin.auth().createCustomToken(firebaseUid, {
        provider: 'kakao',
        email: email || null,
        name: displayName || 'Kakao User',
        picture: photoUrl || null,
      });
      
      // (선택) Firestore에 사용자 정보 저장
      await admin.firestore().collection('users').doc(firebaseUid).set({
        uid: firebaseUid,
        provider: 'kakao',
        kakaoUid: kakaoUid,
        email: email || null,
        displayName: displayName || 'Kakao User',
        photoURL: photoUrl || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      return { customToken };
      
    } catch (error) {
      console.error('Error creating custom token for Kakao:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        `Failed to create custom token: ${error.message}`
      );
    }
  });
```

### 3.2 Flutter 클라이언트 호출

**파일**: `lib/services/social_login_service.dart` (TODO 구현 부분)

```dart
Future<SocialLoginResult> signInWithKakao() async {
  try {
    // 1. 카카오 로그인으로 사용자 정보 획득
    final user = await UserApi.instance.loginWithKakaoTalk();
    final account = user.kakaoAccount;
    
    // 2. Firebase Functions 호출하여 Custom Token 생성
    final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
    final callable = functions.httpsCallable('createCustomTokenForKakao');
    
    final result = await callable.call<Map<String, dynamic>>({
      'kakaoUid': user.id.toString(),
      'email': account?.email,
      'displayName': account?.profile?.nickname,
      'photoUrl': account?.profile?.profileImageUrl,
    });
    
    final customToken = result.data['customToken'] as String;
    
    // 3. Custom Token으로 Firebase Authentication 로그인
    final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
    
    return SocialLoginResult(
      success: true,
      userId: userCredential.user?.uid,
      email: account?.email,
      displayName: account?.profile?.nickname,
      photoUrl: account?.profile?.profileImageUrl,
      provider: SocialLoginProvider.kakao,
    );
    
  } catch (e) {
    return SocialLoginResult(
      success: false,
      errorMessage: e.toString(),
      provider: SocialLoginProvider.kakao,
    );
  }
}
```

---

## 4. 네이버 Custom Token 엔드포인트

### 4.1 함수 구현

**파일**: `functions/index.js`

```javascript
/**
 * 네이버 로그인용 Firebase Custom Token 생성
 * 
 * @param {object} data - 요청 데이터
 * @param {string} data.naverId - 네이버 사용자 ID
 * @param {string} data.email - 네이버 계정 이메일
 * @param {string} data.nickname - 네이버 닉네임
 * @param {string} data.profileImage - 네이버 프로필 이미지
 * @param {string} data.accessToken - 네이버 Access Token (검증용, 선택)
 * 
 * @returns {object} { customToken: string }
 */
exports.createCustomTokenForNaver = functions
  .region('asia-northeast3') // 서울 리전
  .https.onCall(async (data, context) => {
    try {
      // 입력 검증
      const { naverId, email, nickname, profileImage, accessToken } = data;
      
      if (!naverId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'naverId is required'
        );
      }
      
      // (선택) 네이버 Access Token 검증
      // 프로덕션에서는 네이버 API를 호출하여 토큰 유효성 검증 권장
      // if (accessToken) {
      //   const axios = require('axios');
      //   const response = await axios.get('https://openapi.naver.com/v1/nid/me', {
      //     headers: { Authorization: `Bearer ${accessToken}` }
      //   });
      //   
      //   if (response.data.response.id !== naverId) {
      //     throw new functions.https.HttpsError('permission-denied', 'Invalid token');
      //   }
      // }
      
      // Firebase UID 생성 (prefix로 구분)
      const firebaseUid = `naver_${naverId}`;
      
      console.log(`Creating custom token for Naver user: ${firebaseUid}`);
      
      // Custom Token 생성
      const customToken = await admin.auth().createCustomToken(firebaseUid, {
        provider: 'naver',
        email: email || null,
        name: nickname || 'Naver User',
        picture: profileImage || null,
      });
      
      // (선택) Firestore에 사용자 정보 저장
      await admin.firestore().collection('users').doc(firebaseUid).set({
        uid: firebaseUid,
        provider: 'naver',
        naverId: naverId,
        email: email || null,
        displayName: nickname || 'Naver User',
        photoURL: profileImage || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      
      return { customToken };
      
    } catch (error) {
      console.error('Error creating custom token for Naver:', error);
      
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      
      throw new functions.https.HttpsError(
        'internal',
        `Failed to create custom token: ${error.message}`
      );
    }
  });
```

### 4.2 Flutter 클라이언트 호출

**파일**: `lib/services/social_login_service.dart` (TODO 구현 부분)

```dart
Future<SocialLoginResult> signInWithNaver() async {
  try {
    // 1. 네이버 로그인으로 사용자 정보 획득
    final result = await FlutterNaverLogin.logIn();
    
    if (result.status != NaverLoginStatus.loggedIn) {
      throw Exception('Naver login failed');
    }
    
    final account = result.account;
    
    // 2. Firebase Functions 호출하여 Custom Token 생성
    final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
    final callable = functions.httpsCallable('createCustomTokenForNaver');
    
    final funcResult = await callable.call<Map<String, dynamic>>({
      'naverId': account.id,
      'email': account.email,
      'nickname': account.nickname,
      'profileImage': account.profileImage,
    });
    
    final customToken = funcResult.data['customToken'] as String;
    
    // 3. Custom Token으로 Firebase Authentication 로그인
    final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
    
    return SocialLoginResult(
      success: true,
      userId: userCredential.user?.uid,
      email: account.email,
      displayName: account.nickname,
      photoUrl: account.profileImage,
      provider: SocialLoginProvider.naver,
    );
    
  } catch (e) {
    return SocialLoginResult(
      success: false,
      errorMessage: e.toString(),
      provider: SocialLoginProvider.naver,
    );
  }
}
```

---

## 5. 보안 고려사항

### 5.1 액세스 토큰 검증 (권장)

프로덕션 환경에서는 클라이언트가 제공한 소셜 로그인 Access Token을 백엔드에서 검증해야 합니다.

**카카오 토큰 검증**:

```javascript
const axios = require('axios');

async function verifyKakaoToken(accessToken) {
  try {
    const response = await axios.get('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    
    return {
      valid: true,
      kakaoUid: response.data.id.toString(),
      email: response.data.kakao_account?.email,
    };
  } catch (error) {
    return { valid: false };
  }
}
```

**네이버 토큰 검증**:

```javascript
async function verifyNaverToken(accessToken) {
  try {
    const response = await axios.get('https://openapi.naver.com/v1/nid/me', {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    
    return {
      valid: true,
      naverId: response.data.response.id,
      email: response.data.response.email,
    };
  } catch (error) {
    return { valid: false };
  }
}
```

### 5.2 Rate Limiting

Custom Token 생성 엔드포인트에 Rate Limiting 적용:

```javascript
const { RateLimiter } = require('limiter');

// IP당 분당 10회 제한
const limiter = new RateLimiter({ tokensPerInterval: 10, interval: 'minute' });

exports.createCustomTokenForKakao = functions
  .region('asia-northeast3')
  .https.onCall(async (data, context) => {
    // Rate Limiting 체크
    const remainingRequests = await limiter.removeTokens(1);
    if (remainingRequests < 0) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Too many requests. Please try again later.'
      );
    }
    
    // ... 나머지 로직
  });
```

### 5.3 사용자 인증 상태 확인

Firebase Functions는 `context.auth`를 통해 호출자의 인증 상태를 확인할 수 있습니다:

```javascript
exports.updateUserProfile = functions
  .region('asia-northeast3')
  .https.onCall(async (data, context) => {
    // 인증된 사용자만 호출 가능
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }
    
    const uid = context.auth.uid;
    // ... 사용자 정보 업데이트
  });
```

---

## 6. 테스트 방법

### 6.1 로컬 에뮬레이터 테스트

```bash
# Firebase Emulator Suite 설치
npm install -g firebase-tools

# 에뮬레이터 시작
cd /home/user/flutter_app
firebase emulators:start --only functions

# 출력:
# ┌─────────────────────────────────────────────────────────┐
# │ ✔  All emulators ready! It is now safe to connect.     │
# └─────────────────────────────────────────────────────────┘
# 
# ┌───────────┬────────────────┬─────────────────────────────────┐
# │ Emulator  │ Host:Port      │ View in Emulator UI             │
# ├───────────┼────────────────┼─────────────────────────────────┤
# │ Functions │ localhost:5001 │ http://localhost:4000/functions │
# └───────────┴────────────────┴─────────────────────────────────┘
```

**Flutter 앱에서 에뮬레이터 사용**:

```dart
// lib/main.dart에서 에뮬레이터 설정 추가
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(...);
  
  // 🧪 개발 환경: Firebase Functions 에뮬레이터 사용
  if (kDebugMode) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
  
  runApp(const MyApp());
}
```

### 6.2 프로덕션 배포

```bash
# Functions 배포
firebase deploy --only functions

# 특정 함수만 배포
firebase deploy --only functions:createCustomTokenForKakao
firebase deploy --only functions:createCustomTokenForNaver

# 배포 완료 후 URL 확인:
# https://asia-northeast3-[PROJECT_ID].cloudfunctions.net/createCustomTokenForKakao
```

### 6.3 Postman/curl 테스트

**curl 예시 (카카오)**:

```bash
curl -X POST \
  https://asia-northeast3-[PROJECT_ID].cloudfunctions.net/createCustomTokenForKakao \
  -H 'Content-Type: application/json' \
  -d '{
    "data": {
      "kakaoUid": "1234567890",
      "email": "user@example.com",
      "displayName": "테스트 사용자",
      "photoUrl": "https://example.com/photo.jpg"
    }
  }'

# 예상 응답:
# {
#   "result": {
#     "customToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
#   }
# }
```

---

## ✅ 체크리스트

배포 전 확인사항:

### Firebase Functions 설정
- [ ] Firebase CLI 설치 및 로그인
- [ ] `firebase-admin`, `firebase-functions` 패키지 설치
- [ ] 환경 변수 설정 (필요 시)
- [ ] 리전 설정 (`asia-northeast3`)

### 카카오 Custom Token
- [ ] `createCustomTokenForKakao` 함수 구현
- [ ] 입력 검증 로직 추가
- [ ] (선택) Access Token 검증 구현
- [ ] Firestore에 사용자 정보 저장
- [ ] Flutter 클라이언트 통합

### 네이버 Custom Token
- [ ] `createCustomTokenForNaver` 함수 구현
- [ ] 입력 검증 로직 추가
- [ ] (선택) Access Token 검증 구현
- [ ] Firestore에 사용자 정보 저장
- [ ] Flutter 클라이언트 통합

### 보안
- [ ] Rate Limiting 적용
- [ ] Access Token 검증 (프로덕션)
- [ ] 에러 처리 및 로깅
- [ ] CORS 설정 확인

### 테스트
- [ ] 로컬 에뮬레이터 테스트
- [ ] 프로덕션 배포 및 테스트
- [ ] Flutter 앱에서 End-to-End 테스트
- [ ] Firebase Console에서 사용자 인증 확인

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-01-29  
**작성자**: MAKECALL Development Team
