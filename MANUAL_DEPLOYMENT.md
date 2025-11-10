# Firebase Functions 수동 배포 가이드

## 🚨 배포 권한 문제 해결

Firebase CLI를 통한 자동 배포 시 다음과 같은 권한 오류가 발생합니다:

```
Error: Request to https://cloudresourcemanager.googleapis.com/v1/projects/staging had HTTP Error: 403, 
The caller does not have permission
```

**원인:**
- 서비스 계정 (`firebase-admin-sdk.json`)은 Firestore/FCM 작업 권한만 있음
- Cloud Functions 배포 권한이 없음
- Firebase CLI는 사용자 OAuth 인증이 필요함

**해결 방법:**
Firebase Console 웹 UI를 통한 수동 배포

---

## 📦 준비된 배포 파일

✅ **functions.zip** 파일이 준비되었습니다!

**파일 위치:** `/home/user/flutter_app/functions.zip`

**파일 크기:** 92KB

**포함된 내용:**
- `index.js` - 11개 Cloud Functions 소스 코드
- `package.json` - Dependencies 정의
- `package-lock.json` - Dependencies 버전 잠금
- `DEPLOYMENT_GUIDE.md` - 배포 가이드
- `CHANGELOG.md` - 변경 이력
- `README.md` - 함수 설명

**제외된 내용:**
- `node_modules/` - 배포 시 자동 설치됨
- `.eslintrc.js` - 개발 환경 설정

---

## 🚀 Firebase Console 수동 배포 방법

### 방법 1: Cloud Functions UI (권장)

#### Step 1: Firebase Console 접속
1. 브라우저에서 [Firebase Console](https://console.firebase.google.com/) 접속
2. `makecallio` 프로젝트 클릭

#### Step 2: Functions 메뉴 이동
1. 왼쪽 메뉴에서 **"Functions"** 클릭
2. 함수 목록 페이지로 이동

#### Step 3: functions.zip 다운로드
```bash
# 로컬 컴퓨터로 다운로드
# 샌드박스에서 다운로드 링크 사용:
```

**다운로드 링크:** 
`https://www.genspark.ai/api/code_sandbox/download_file_stream?project_id=<PROJECT_ID>&file_path=%2Fhome%2Fuser%2Fflutter_app%2Ffunctions.zip&file_name=functions.zip`

#### Step 4: 소스 코드 업로드
1. **"함수 만들기"** 또는 **"소스 코드"** 탭 클릭
2. **"ZIP 업로드"** 옵션 선택
3. 다운로드한 `functions.zip` 파일 선택
4. **"배포"** 버튼 클릭

#### Step 5: 배포 진행 확인
- 배포 진행 상황 표시됨 (약 3-5분 소요)
- 각 함수별 배포 상태 확인 가능
- 11개 함수 모두 ✅ 초록색이 되면 완료

---

### 방법 2: Google Cloud Console (대안)

#### Step 1: Cloud Console 접속
1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 선택: `makecallio`

#### Step 2: Cloud Functions 메뉴
1. 왼쪽 메뉴에서 **"Cloud Functions"** 클릭
2. **"함수 만들기"** 버튼 클릭

#### Step 3: 함수 설정
**기본 설정:**
- 함수 이름: `sendIncomingCallNotification` (예시)
- 리전: `asia-east1`
- 트리거 유형: Cloud Firestore

**런타임 설정:**
- 런타임: Node.js 20
- 진입점: 함수 이름 (예: `sendIncomingCallNotification`)

#### Step 4: 소스 코드 업로드
1. **"ZIP 업로드"** 선택
2. Cloud Storage 버킷 선택 또는 생성
3. `functions.zip` 파일 업로드
4. **"배포"** 버튼 클릭

#### Step 5: 나머지 10개 함수 반복
각 함수마다 위 과정 반복 (시간 소요 많음)

---

### 방법 3: Firebase CLI + OAuth 인증 (로컬 PC에서)

로컬 PC에 Firebase CLI가 설치되어 있다면:

#### Step 1: Firebase CLI 설치
```bash
npm install -g firebase-tools
```

#### Step 2: Firebase 로그인
```bash
firebase login
```
- 브라우저에서 Google 계정 로그인
- Firebase 프로젝트 접근 권한 허용

#### Step 3: functions.zip 다운로드 및 압축 해제
```bash
# functions.zip 다운로드
# 압축 해제
unzip functions.zip

# Flutter 프로젝트 디렉토리로 이동
cd flutter_app/
```

#### Step 4: Firebase 프로젝트 설정
```bash
# 프로젝트 선택
firebase use makecallio

# 프로젝트 확인
firebase projects:list
```

#### Step 5: Functions 배포
```bash
# 모든 함수 배포
firebase deploy --only functions

# 또는 특정 함수만 배포
firebase deploy --only functions:sendIncomingCallNotification
```

---

## 📋 배포된 함수 목록 (11개)

배포 후 다음 함수들이 생성됩니다:

### Firestore Triggers (자동 실행)
1. ✅ **sendForceLogoutNotification**
   - Trigger: `fcm_force_logout_queue/{queueId}` 생성
   - URL: 없음 (Firestore 트리거)

2. ✅ **sendIncomingCallNotification**
   - Trigger: `incoming_calls/{callId}` 생성
   - URL: 없음 (Firestore 트리거)

3. ✅ **sendCallStatusNotification**
   - Trigger: `call_history/{historyId}` 업데이트
   - URL: 없음 (Firestore 트리거)

### Callable Functions (앱에서 호출)
4. ✅ **remoteLogout**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/remoteLogout`
   - 호출 방법: `FirebaseFunctions.instance.httpsCallable('remoteLogout')`

5. ✅ **cleanupExpiredTokens**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens`

6. ✅ **manualCleanupTokens**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/manualCleanupTokens`

7. ✅ **sendGroupMessage**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/sendGroupMessage`

8. ✅ **processScheduledNotifications**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications`

9. ✅ **sendCustomNotification**
   - URL: `https://asia-east1-makecallio.cloudfunctions.net/sendCustomNotification`

10. ✅ **subscribeWebPush**
    - URL: `https://asia-east1-makecallio.cloudfunctions.net/subscribeWebPush`

11. ✅ **validateAllTokens**
    - URL: `https://asia-east1-makecallio.cloudfunctions.net/validateAllTokens`

### HTTP Functions (REST API)
12. ✅ **getNotificationStats**
    - URL: `https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats`
    - 호출 방법: `curl https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats`

---

## ✅ 배포 후 확인 사항

### 1. Firebase Console에서 확인
1. [Firebase Console - Functions](https://console.firebase.google.com/project/makecallio/functions) 접속
2. 11개 함수가 모두 ✅ 초록색 상태인지 확인
3. 각 함수 클릭하여 상세 정보 확인

### 2. 함수 테스트

**Firestore Trigger 테스트:**
```dart
// incoming_calls 컬렉션에 문서 생성
await FirebaseFirestore.instance.collection('incoming_calls').add({
  'userId': 'test_user',
  'callerNumber': '010-1234-5678',
  'callerName': '홍길동',
  'extension': '1001',
  'timestamp': FieldValue.serverTimestamp(),
});
// → sendIncomingCallNotification 자동 실행됨
```

**Callable Function 테스트:**
```dart
// Flutter 앱에서
final callable = FirebaseFunctions.instance
    .httpsCallable('getNotificationStats');
final result = await callable.call();
print('Stats: ${result.data}');
```

**HTTP Function 테스트:**
```bash
curl https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
```

### 3. 로그 확인

**Firebase Console:**
1. Functions 메뉴 → 함수 선택
2. **"로그"** 탭 클릭
3. 실시간 로그 확인

**Cloud Logging:**
1. [Cloud Logging Console](https://console.cloud.google.com/logs/query?project=makecallio) 접속
2. 필터 적용:
   ```
   resource.type="cloud_function"
   resource.labels.function_name="sendIncomingCallNotification"
   ```

---

## 🔧 문제 해결

### 배포 실패 시

**증상:** 함수가 ❌ 빨간색 상태

**확인 사항:**
1. **로그 확인**: 에러 메시지 확인
2. **권한 확인**: Cloud Functions 서비스 계정 권한
3. **코드 문법**: ESLint 검사 결과
4. **Dependencies**: package.json 버전 확인

**해결 방법:**
```bash
# 로컬에서 문법 검사
cd functions
npm install
npm run lint
node -c index.js
```

### 함수 실행 실패 시

**증상:** 함수는 배포되었지만 실행 시 오류

**확인 사항:**
1. **Firestore 규칙**: Functions가 Firestore 접근 가능한지
2. **FCM 설정**: google-services.json 설정 확인
3. **환경 변수**: 필요한 환경 변수 설정 확인

**Firestore 규칙 확인:**
```javascript
// Firestore Rules
service cloud.firestore {
  match /databases/{database}/documents {
    // Cloud Functions가 모든 컬렉션 읽기/쓰기 가능
    match /{document=**} {
      allow read, write: if request.auth != null || request.resource.data != null;
    }
  }
}
```

### 권한 오류 시

**증상:** 403 Permission Denied

**해결 방법:**
1. [IAM 설정](https://console.cloud.google.com/iam-admin/iam?project=makecallio) 접속
2. Cloud Functions 서비스 계정 확인
3. 필요한 역할 추가:
   - Cloud Functions Developer
   - Firestore User
   - Firebase Admin

---

## 📊 배포 상태 요약

**✅ 준비 완료:**
- Firebase Functions v2 코드 작성 완료
- Logger import 오류 수정 완료
- ESLint 검사 통과
- JavaScript 문법 검사 통과
- functions.zip 파일 생성 완료

**⏳ 사용자 작업 필요:**
- Firebase Console 로그인
- functions.zip 다운로드
- Firebase Console에서 수동 업로드
- 배포 완료 확인

**📍 배포 정보:**
- 프로젝트: `makecallio`
- Region: `asia-east1`
- 함수 수: 11개
- 코드 상태: 배포 준비 완료 ✅

---

## 💡 추천 배포 방법

### 최우선 추천: Firebase Console 웹 UI
- ✅ 가장 간단함
- ✅ 권한 문제 없음
- ✅ 시각적 진행 상황 확인
- ⚠️  단점: ZIP 파일 수동 업로드 필요

### 대안: 로컬 PC에서 Firebase CLI
- ✅ 자동화 가능
- ✅ 버전 관리 편리
- ⚠️  로컬 PC에 Firebase CLI 설치 필요
- ⚠️  OAuth 인증 필요

---

## 📚 관련 문서

- [DEPLOYMENT_GUIDE.md](./functions/DEPLOYMENT_GUIDE.md) - 상세 배포 가이드
- [CHANGELOG.md](./functions/CHANGELOG.md) - 코드 변경 이력
- [functions/index.js](./functions/index.js) - 함수 소스 코드

---

## 📞 추가 지원

문제가 계속되면 다음을 확인하세요:

1. **Firebase Status**: https://status.firebase.google.com/
2. **Cloud Status**: https://status.cloud.google.com/
3. **Firebase Support**: https://firebase.google.com/support

---

**다운로드 파일:** `/home/user/flutter_app/functions.zip` (92KB)

**다음 단계:** 
1. functions.zip 다운로드
2. Firebase Console 접속
3. Functions 메뉴에서 업로드
4. 배포 완료 확인 ✅
