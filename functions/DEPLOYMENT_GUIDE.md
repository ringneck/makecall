# Firebase Functions 배포 가이드

## ✅ 코드 검증 완료

### 검증 항목
- ✅ **Firebase Functions v2 적용 완료**: 모든 11개 함수가 v2 API 사용
- ✅ **Logger 수정 완료**: `require("firebase-functions/v2")` 사용
- ✅ **ESLint 검사 통과**: 코드 스타일 및 문법 오류 없음
- ✅ **JavaScript 문법 검사 통과**: Node.js 문법 오류 없음
- ✅ **Dependencies 설치 완료**: firebase-functions v5.0.0, firebase-admin v12.0.0

### 배포된 함수 목록 (11개)

#### 1. Firestore Triggers (3개)
- `sendForceLogoutNotification` - 중복 로그인 시 강제 로그아웃 알림
- `sendIncomingCallNotification` - 착신 전화 실시간 알림
- `sendCallStatusNotification` - 통화 상태 변경 알림

#### 2. Callable Functions (7개)
- `remoteLogout` - 원격 기기 로그아웃
- `cleanupExpiredTokens` - 만료된 FCM 토큰 정리
- `manualCleanupTokens` - 수동 토큰 정리 (cleanupExpiredTokens 별칭)
- `sendGroupMessage` - 그룹 메시지 브로드캐스트
- `processScheduledNotifications` - 예약 알림 처리
- `sendCustomNotification` - 사용자 지정 알림
- `subscribeWebPush` - 웹푸시 구독 관리
- `validateAllTokens` - 전체 FCM 토큰 유효성 검사

#### 3. HTTP Functions (1개)
- `getNotificationStats` - 알림 통계 조회 API

---

## 🚀 배포 방법

### 방법 1: Firebase Console에서 직접 배포

Firebase Console의 웹 UI를 사용하여 배포할 수 있습니다.

**단계:**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. `makecallio` 프로젝트 선택
3. 좌측 메뉴에서 **Functions** 클릭
4. **소스 코드** 탭 선택
5. 전체 `functions` 디렉토리를 ZIP으로 압축
6. **업로드** 버튼 클릭하여 ZIP 파일 업로드
7. 배포 진행 상황 확인

### 방법 2: Firebase CLI 배포 (권장)

Firebase CLI를 사용하여 명령줄에서 배포합니다.

**사전 준비:**
```bash
# Firebase CLI 설치 (이미 설치됨)
npm install -g firebase-tools

# Firebase 로그인
firebase login
```

**배포 명령:**
```bash
cd /home/user/flutter_app
firebase deploy --only functions
```

**특정 함수만 배포:**
```bash
# 단일 함수 배포
firebase deploy --only functions:sendIncomingCallNotification

# 여러 함수 배포
firebase deploy --only functions:sendIncomingCallNotification,functions:remoteLogout
```

### 방법 3: GitHub Actions 자동 배포 (CI/CD)

GitHub Actions를 사용하여 코드 푸시 시 자동 배포할 수 있습니다.

**`.github/workflows/firebase-functions.yml` 파일 생성:**
```yaml
name: Deploy Firebase Functions

on:
  push:
    branches:
      - main
    paths:
      - 'functions/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install Dependencies
        run: |
          cd functions
          npm ci
      
      - name: Deploy to Firebase
        run: |
          npm install -g firebase-tools
          firebase deploy --only functions --token ${{ secrets.FIREBASE_TOKEN }}
```

**Firebase Token 생성:**
```bash
firebase login:ci
```
생성된 토큰을 GitHub Repository의 Secrets에 `FIREBASE_TOKEN`으로 등록하세요.

---

## 🧪 로컬 테스트

### Firebase Emulator Suite 사용

배포 전 로컬에서 함수를 테스트할 수 있습니다.

**Emulator 시작:**
```bash
cd /home/user/flutter_app
firebase emulators:start --only functions
```

**Emulator UI 접속:**
```
http://localhost:4000
```

**함수 호출 테스트:**
```bash
# Callable Function 호출
curl -X POST http://localhost:5001/makecallio/asia-east1/remoteLogout \
  -H "Content-Type: application/json" \
  -d '{"data": {"targetUserId": "user123", "targetDeviceId": "device456"}}'

# HTTP Function 호출
curl http://localhost:5001/makecallio/asia-east1/getNotificationStats
```

---

## 📊 배포 후 확인

### 1. Firebase Console에서 확인

**Functions 대시보드:**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. `makecallio` 프로젝트 선택
3. **Functions** 메뉴 클릭
4. 배포된 함수 목록 확인

**배포 상태 확인:**
- ✅ 초록색: 정상 배포 및 실행 중
- ⚠️  노란색: 경고 (실행은 되지만 문제 있음)
- ❌ 빨간색: 오류 (실행 실패)

### 2. 함수 로그 확인

**실시간 로그 보기:**
```bash
firebase functions:log
```

**특정 함수 로그:**
```bash
firebase functions:log --only sendIncomingCallNotification
```

**Cloud Logging Console:**
https://console.cloud.google.com/logs/query?project=makecallio

### 3. 함수 테스트

**Callable Function 테스트 (Flutter 앱에서):**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('remoteLogout');
final result = await callable.call({
  'targetUserId': 'user123',
  'targetDeviceId': 'device456',
});
print('Result: ${result.data}');
```

**HTTP Function 테스트:**
```bash
curl https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
```

---

## 🔧 트러블슈팅

### TypeError: Cannot read properties of undefined (reading 'info')

**원인:** `logger` import 오류

**해결 완료:** ✅ `require("firebase-functions/v2")` 사용하도록 수정됨

### 403 Permission Denied

**원인:** Firebase CLI 권한 부족

**해결 방법:**
```bash
# Firebase 로그인 다시 시도
firebase logout
firebase login

# 프로젝트 설정 확인
firebase use makecallio
```

### 함수 배포는 성공했지만 실행 시 오류

**확인 사항:**
1. **Firestore 규칙 확인**: Functions가 Firestore에 접근할 수 있는지 확인
2. **IAM 권한 확인**: Cloud Functions 서비스 계정 권한 확인
3. **환경 변수 확인**: 필요한 환경 변수가 설정되어 있는지 확인

**로그 확인:**
```bash
firebase functions:log --limit 100
```

### 배포 시간이 너무 오래 걸림

**원인:** 11개 함수를 한 번에 배포

**해결 방법:**
```bash
# 변경된 함수만 배포
firebase deploy --only functions:sendIncomingCallNotification

# 또는 병렬 배포 옵션 사용
firebase deploy --only functions --force
```

---

## 📝 배포 체크리스트

### 배포 전
- [ ] ESLint 검사 통과 (`npm run lint`)
- [ ] JavaScript 문법 검사 통과
- [ ] 로컬 에뮬레이터로 테스트 완료
- [ ] Firebase 로그인 완료 (`firebase login`)
- [ ] 프로젝트 선택 확인 (`firebase use makecallio`)

### 배포 중
- [ ] 배포 명령 실행 (`firebase deploy --only functions`)
- [ ] 배포 로그 확인 (오류 없음)
- [ ] 배포 완료 메시지 확인

### 배포 후
- [ ] Firebase Console에서 함수 상태 확인
- [ ] 함수 로그 확인 (`firebase functions:log`)
- [ ] 테스트 메시지 전송하여 동작 확인
- [ ] 에러 없이 정상 실행 확인

---

## 🎯 추가 정보

### Region 설정
모든 함수는 `asia-east1` (대만) 리전에 배포됩니다.
- 한국과 가장 가까운 리전
- 낮은 지연 시간
- 비용 효율적

### 비용 관리
- **Free Tier**: 월 200만 호출 무료
- **Invocations**: 함수 호출 횟수
- **Compute Time**: 실행 시간 (GB-seconds)
- **Networking**: 네트워크 트래픽

**비용 확인:**
https://console.firebase.google.com/project/makecallio/usage

### 성능 모니터링
- **Firebase Performance Monitoring** 활성화
- **Cloud Monitoring** 대시보드 확인
- **Error Reporting** 자동 수집

---

## 📚 참고 자료

- [Firebase Functions v2 문서](https://firebase.google.com/docs/functions/2nd-gen)
- [Firebase Cloud Messaging 가이드](https://firebase.google.com/docs/cloud-messaging)
- [Firebase CLI 참조](https://firebase.google.com/docs/cli)
- [Google Cloud Functions 문서](https://cloud.google.com/functions/docs)

---

## ✅ 현재 상태 요약

**코드 상태:**
- ✅ Firebase Functions v2 완전 적용
- ✅ Logger 오류 수정 완료
- ✅ ESLint 검사 통과
- ✅ 문법 검사 통과
- ✅ 배포 준비 완료

**다음 단계:**
1. Firebase CLI로 로그인: `firebase login`
2. 함수 배포: `firebase deploy --only functions`
3. 배포 상태 확인
4. 테스트 메시지로 동작 확인

**배포 위치:**
- 프로젝트: `makecallio`
- 리전: `asia-east1`
- 함수 수: 11개
