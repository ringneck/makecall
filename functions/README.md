# MAKECALL Cloud Functions

Firebase Cloud Functions for duplicate login prevention and remote logout functionality.

## 기능

### 1. 강제 로그아웃 FCM 메시지 전송 (`sendForceLogoutNotification`)
- **트리거**: Firestore 문서 생성 (`fcm_force_logout_queue/{queueId}`)
- **동작**: 중복 로그인 감지 시 기존 기기에 FCM 푸시 알림 전송
- **자동 실행**: 앱에서 중복 로그인 감지 시 자동으로 큐에 추가되어 실행

### 2. 원격 로그아웃 (`remoteLogout`)
- **타입**: Callable Function
- **용도**: 활성 세션 관리 UI에서 특정 기기를 원격으로 로그아웃
- **권한**: 본인의 기기만 로그아웃 가능

### 3. 만료된 토큰 정리 (`cleanupExpiredTokens`)
- **타입**: Callable Function (스케줄 실행 권장)
- **동작**: 30일 이상 미사용 FCM 토큰 자동 삭제
- **권장 스케줄**: 매일 자정

## 설치 및 배포

### 1. Firebase CLI 설치
```bash
npm install -g firebase-tools
```

### 2. Firebase 로그인
```bash
firebase login
```

### 3. 프로젝트 초기화 (최초 1회)
```bash
cd /path/to/flutter_app
firebase init functions
```

선택 옵션:
- **Project**: 기존 프로젝트 선택 (makecallio)
- **Language**: JavaScript
- **ESLint**: Yes
- **Dependencies**: Yes (npm install)

### 4. 의존성 설치
```bash
cd functions
npm install
```

### 5. Cloud Functions 배포
```bash
# 모든 함수 배포
firebase deploy --only functions

# 특정 함수만 배포
firebase deploy --only functions:sendForceLogoutNotification
firebase deploy --only functions:remoteLogout
firebase deploy --only functions:cleanupExpiredTokens
```

## 로그 모니터링

### 실시간 로그 확인
```bash
firebase functions:log
```

### 특정 함수 로그만 확인
```bash
firebase functions:log --only sendForceLogoutNotification
```

### Firebase Console에서 확인
1. Firebase Console 접속
2. Functions 탭 선택
3. Logs 탭에서 실시간 로그 확인

## 테스트

### 로컬 에뮬레이터 실행
```bash
cd functions
npm run serve
```

### 원격 로그아웃 테스트 (Flutter에서 호출)
```dart
final callable = FirebaseFunctions.instance.httpsCallable('remoteLogout');
final result = await callable.call({
  'targetDeviceId': 'device_123',
  'targetUserId': 'user_123',
});
```

## 비용 관리

### 무료 할당량 (Spark Plan)
- Cloud Functions 호출: 2백만 회/월
- Firestore 읽기: 50,000 회/일
- Firestore 쓰기: 20,000 회/일

### 예상 사용량
- **중복 로그인**: 사용자당 로그인 시 1회 (매우 낮음)
- **원격 로그아웃**: 사용자 수동 실행 (매우 낮음)
- **토큰 정리**: 1회/일 (매우 낮음)

**결론**: 대부분의 경우 무료 할당량 내에서 운영 가능

## 보안 규칙

Firestore `fcm_force_logout_queue` 컬렉션 보안 규칙:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // FCM 강제 로그아웃 큐: 인증된 사용자만 생성 가능
    match /fcm_force_logout_queue/{queueId} {
      allow create: if request.auth != null;
      allow read, update, delete: if false; // Cloud Functions만 접근
    }
    
    // FCM 토큰: 본인 토큰만 읽기/쓰기 가능
    match /fcm_tokens/{tokenId} {
      allow read, write: if request.auth != null && 
                             tokenId.matches(request.auth.uid + '_.*');
    }
  }
}
```

## 문제 해결

### 1. 배포 실패
```bash
# Firebase CLI 업데이트
npm install -g firebase-tools@latest

# 프로젝트 재선택
firebase use --add
```

### 2. FCM 메시지 전송 실패
- Firebase Console에서 Cloud Messaging API 활성화 확인
- FCM 토큰 유효성 확인
- Functions 로그에서 에러 메시지 확인

### 3. 권한 오류
```bash
# Firebase 프로젝트 권한 확인
firebase projects:list

# IAM 역할 확인 (Firebase Console)
# Project Settings → Users and permissions
```

## 업그레이드 가이드

### Blaze Plan (종량제) 전환 시 추가 기능
- 스케줄러를 사용한 자동 토큰 정리
- 더 많은 FCM 메시지 전송 가능
- 외부 API 호출 가능

## 지원

문제 발생 시:
1. Functions 로그 확인: `firebase functions:log`
2. Firebase Console → Functions → Logs 확인
3. GitHub Issues 등록
