# 🔍 ADB Logcat으로 FCM 푸시 알림 디버깅하기

## 📋 사전 준비

### 1. USB 디버깅 활성화
```
기기 설정 → 개발자 옵션 → USB 디버깅 활성화
```

**개발자 옵션이 없는 경우:**
```
설정 → 휴대전화 정보 → 빌드 번호를 7번 연속 탭
```

### 2. 기기를 컴퓨터에 USB 연결
- USB 케이블로 연결
- 화면에 "USB 디버깅 허용" 팝업 → "허용" 클릭

### 3. ADB 설치 확인
```bash
# Windows
adb version

# Mac/Linux
adb version
```

**ADB가 없는 경우:**
- **Windows**: [Android SDK Platform Tools 다운로드](https://developer.android.com/studio/releases/platform-tools)
- **Mac**: `brew install android-platform-tools`
- **Linux**: `sudo apt install adb`

---

## 🔬 기본 FCM 로그 수집

### 1. FCM 관련 로그만 필터링
```bash
adb logcat | grep -E "(FirebaseMessaging|FCM|GCM|TokenRefresh)"
```

**출력 예시 (정상 작동 시):**
```
I/FirebaseMessaging: Token refreshing enabled
D/FirebaseMessaging: Token: d1234567890abcdef...
I/FCM: Received FCM message
D/FCM: Message notification data: {title=테스트, body=푸시 알림 테스트}
I/FirebaseMessaging: Displaying notification
```

---

## 🚨 에러 패턴별 진단

### 1. "INVALID_SENDER" 에러
```
E/FirebaseMessaging: Error receiving FCM: INVALID_SENDER
```

**원인:**
- google-services.json이 올바르지 않음
- Firebase 프로젝트 ID 불일치

**해결 방법:**
1. Firebase Console에서 google-services.json 재다운로드
2. `android/app/google-services.json` 교체
3. APK 재빌드

---

### 2. "MismatchSenderId" 에러
```
E/FirebaseMessaging: Error: MismatchSenderId
```

**원인:**
- 서버에서 전송한 Sender ID와 앱의 Sender ID 불일치
- 다른 Firebase 프로젝트의 토큰 사용

**해결 방법:**
1. Firestore `fcm_tokens` 컬렉션에서 FCM 토큰 재확인
2. Firebase Console에서 프로젝트 Sender ID 확인
3. 앱 재설치 후 새 토큰 생성

---

### 3. "NOT_REGISTERED" 에러
```
E/FirebaseMessaging: Error: NOT_REGISTERED
```

**원인:**
- FCM 토큰이 만료되었거나 삭제됨
- 앱을 삭제했다가 재설치한 경우

**해결 방법:**
1. 앱 재실행하여 새 토큰 생성
2. Firestore에 새 토큰 저장 확인

---

### 4. "SERVICE_NOT_AVAILABLE" 에러
```
E/FirebaseMessaging: Error: SERVICE_NOT_AVAILABLE
```

**원인:**
- Google Play Services가 설치되지 않았거나 업데이트 필요
- 네트워크 연결 문제

**해결 방법:**
1. Google Play Services 업데이트
2. Wi-Fi/데이터 연결 확인
3. 기기 재부팅

---

### 5. "Authentication failed" 에러
```
E/FirebaseAuth: Authentication failed: [firebase_auth/internal-error]
W/FirebaseMessaging: Token request failed: Authentication failed
```

**원인:**
- Firebase API Key 오류
- SHA-1 Fingerprint 미등록

**해결 방법:**
1. Firebase Console에서 SHA-1 등록
2. google-services.json 재다운로드
3. APK 재빌드

---

## 🎯 실시간 FCM 테스트 프로세스

### Step 1: Logcat 시작
```bash
adb logcat -c  # 이전 로그 삭제
adb logcat | grep -E "(FirebaseMessaging|FCM|GCM)"
```

### Step 2: 앱 실행 및 로그인
**예상 로그:**
```
I/FirebaseApp: Device unlocking...
D/FirebaseAuth: Signing in user: user123
I/FirebaseMessaging: Token: d1234567890abcdef...
D/FCM: Token saved to Firestore
```

**⚠️ 문제 발생 시:**
```
E/FirebaseMessaging: Token retrieval failed: null
```
→ APNs 토큰 문제 (iOS) 또는 Google Play Services 문제 (Android)

### Step 3: Firebase Console에서 테스트 메시지 전송
```
Firebase Console → Cloud Messaging → 새 캠페인
→ Firebase 알림 메시지 → 단일 기기 선택
→ FCM 토큰 입력 → 테스트 메시지 보내기
```

### Step 4: 로그 확인
**✅ 성공 시 (포그라운드):**
```
D/FCM: Received FCM message
D/FCM: Message data: {type=incoming_call, caller_name=홍길동, ...}
I/FirebaseMessaging: Displaying notification
```

**✅ 성공 시 (백그라운드):**
```
D/FCM: Background message received
D/FCM: Notification displayed by system
```

**❌ 실패 시 (조용히 실패):**
```
(로그 없음)
```
→ SHA-1 Fingerprint 미등록 가능성 높음

---

## 🔍 고급 디버깅: 전체 로그 수집

### 풀 로그 수집 (파일로 저장)
```bash
adb logcat > fcm_debug.log

# 30초 후 Ctrl+C로 중지
# fcm_debug.log 파일 확인
```

### 중요한 로그 패턴 검색
```bash
# "error" 또는 "exception" 포함 라인 찾기
grep -i "error\|exception" fcm_debug.log

# Firebase 관련 모든 로그
grep -i "firebase" fcm_debug.log

# 푸시 알림 관련 로그
grep -i "notification" fcm_debug.log
```

---

## 📊 로그 해석 가이드

### 정상 작동 시 로그 흐름

```
1️⃣  앱 시작:
   I/FirebaseApp: Firebase App initialization started
   I/FirebaseApp: Firebase App initialized successfully

2️⃣  FCM 초기화:
   D/FirebaseMessaging: Starting Firebase Messaging initialization
   I/FirebaseMessaging: Token refreshing enabled

3️⃣  토큰 생성:
   D/FirebaseMessaging: Token: d1234567890abcdef...
   D/FCM: Token saved to Firestore

4️⃣  푸시 수신 (포그라운드):
   D/FCM: Received FCM message
   I/FirebaseMessaging: Showing notification

5️⃣  푸시 수신 (백그라운드):
   D/FCM: Background message received
   D/FCM: Notification displayed by system
```

### 문제 발생 시 로그 패턴

```
❌ Firebase 초기화 실패:
   E/FirebaseApp: Failed to initialize Firebase
   E/FirebaseApp: No app configured

❌ 토큰 생성 실패:
   E/FirebaseMessaging: Token retrieval failed: null
   E/FirebaseMessaging: INVALID_SENDER

❌ 푸시 수신 실패:
   (로그 없음) → SHA-1 미등록
   E/FirebaseMessaging: MismatchSenderId
   E/FirebaseMessaging: NOT_REGISTERED
```

---

## 🔧 실전 디버깅 시나리오

### 시나리오 1: 토큰은 생성되는데 푸시가 안 옴

**증상:**
```bash
$ adb logcat | grep FCM
D/FCM: Token: d1234567890abcdef...
D/FCM: Token saved to Firestore
# (푸시 전송 후) ... 로그 없음
```

**진단:**
- FCM 토큰 생성: ✅
- Firestore 저장: ✅
- 푸시 수신: ❌ (로그 없음)

**가능한 원인:**
1. **SHA-1 Fingerprint 미등록** (90% 확률)
2. Firebase Cloud Messaging API 비활성화 (5%)
3. 서버 측 전송 오류 (5%)

**해결 단계:**
```bash
# 1. SHA-1 등록 확인
# Firebase Console → 프로젝트 설정 → SHA 인증서 지문

# 2. API 활성화 확인
# Google Cloud Console → API 및 서비스

# 3. Firebase Console 테스트 메시지 전송
# (서버 문제인지 클라이언트 문제인지 구분)
```

---

### 시나리오 2: "INVALID_SENDER" 에러

**증상:**
```bash
$ adb logcat | grep FirebaseMessaging
E/FirebaseMessaging: Error receiving FCM: INVALID_SENDER
```

**진단:**
- google-services.json 파일 문제

**해결 방법:**
```bash
# 1. Firebase Console에서 최신 google-services.json 다운로드
# 2. android/app/google-services.json 교체
# 3. APK 재빌드
cd /home/user/flutter_app
flutter clean
flutter build apk --release
```

---

### 시나리오 3: 포그라운드에서만 수신됨

**증상:**
```bash
# 앱이 실행 중일 때:
D/FCM: Received FCM message ✅

# 앱을 종료하거나 백그라운드로 보낸 후:
(로그 없음) ❌
```

**진단:**
- 배터리 최적화가 백그라운드 FCM 서비스를 차단

**해결 방법:**
```
설정 → 배터리 → 배터리 최적화
→ 모든 앱 → MAKECALL → 최적화 안 함
```

---

## 📝 디버깅 체크리스트

### FCM 토큰 생성 단계
- [ ] `I/FirebaseApp: Firebase App initialized successfully`
- [ ] `D/FirebaseMessaging: Token: ...` (토큰 출력)
- [ ] `D/FCM: Token saved to Firestore`

### 푸시 수신 단계
- [ ] Firebase Console 테스트 메시지 전송
- [ ] `D/FCM: Received FCM message`
- [ ] `I/FirebaseMessaging: Displaying notification`

### 에러 없음
- [ ] `INVALID_SENDER` 없음
- [ ] `MismatchSenderId` 없음
- [ ] `NOT_REGISTERED` 없음
- [ ] `SERVICE_NOT_AVAILABLE` 없음

---

## 🎯 빠른 문제 해결 플로우차트

```
푸시 알림이 안 될 때:

1. Logcat에 "INVALID_SENDER"?
   YES → google-services.json 재다운로드
   NO → 2번으로

2. Logcat에 FCM 토큰 생성 로그 있음?
   NO → Google Play Services 확인
   YES → 3번으로

3. Firebase Console 테스트 메시지 전송
   수신됨? → 서버 코드 문제
   수신 안 됨 + 로그 없음 → SHA-1 미등록 (90%)

4. SHA-1 등록 후 google-services.json 재다운로드
   → APK 재빌드 → 테스트
```

---

## 🚀 최종 검증

### 모든 단계가 정상일 때의 완전한 로그 흐름

```bash
# 앱 시작
I/FirebaseApp: Firebase App initialization started
I/FirebaseApp: Firebase App initialized successfully
D/FirebaseAuth: Signing in user: user123

# FCM 초기화
D/FirebaseMessaging: Starting Firebase Messaging initialization
I/FirebaseMessaging: Token refreshing enabled
D/FirebaseMessaging: Token: d1234567890abcdef1234567890abcdef...

# Firestore 저장
D/FCM: Saving token to Firestore
D/FCM: Token saved to Firestore: fcm_tokens/user123_5d513e7a5fb1e2d5

# 푸시 수신 (포그라운드)
D/FCM: Received FCM message
D/FCM: Message type: incoming_call
D/FCM: Caller name: 홍길동
D/FCM: Caller number: 02-1234-5678
I/FirebaseMessaging: Displaying notification
I/FirebaseMessaging: Notification displayed successfully

# 푸시 수신 (백그라운드)
D/FCM: Background message received
D/FCM: Notification displayed by system
D/FCM: User tapped notification
D/FCM: Opening incoming call screen
```

**✅ 위 로그가 모두 나타나면 FCM이 완벽하게 작동하는 것입니다!**

---

## 📞 추가 지원

### 로그 파일 공유 방법

디버깅이 어려운 경우 전체 로그를 수집하여 공유:

```bash
# 1. 로그 수집 시작
adb logcat -c  # 이전 로그 삭제
adb logcat > fcm_full_debug.log

# 2. 앱 실행 및 푸시 테스트 (30초)

# 3. Ctrl+C로 중지

# 4. fcm_full_debug.log 파일 확인 및 공유
```

**포함할 정보:**
- Android 버전
- 기기 모델
- Google Play Services 버전
- 앱 패키지 이름
- Firebase 프로젝트 ID

---

## ✅ 마무리

**ADB Logcat은 FCM 문제 진단의 핵심 도구입니다.**

대부분의 경우:
1. **SHA-1 미등록** → 조용히 실패 (로그 없음)
2. **google-services.json 문제** → `INVALID_SENDER` 에러
3. **Google Play Services 문제** → `SERVICE_NOT_AVAILABLE` 에러

**Logcat으로 정확한 원인을 파악하여 빠르게 해결하세요!**
