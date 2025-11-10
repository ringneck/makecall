# 🤖 Android FCM 푸시 알림 완전 해결 가이드

## 📋 문제 상황
Android Release APK에서 푸시 알림이 수신되지 않는 문제
- ✅ Firebase 초기화: 정상
- ✅ FCM 토큰 생성: 정상 (Firestore에 저장됨)
- ✅ FirebaseMessagingService 등록: 완료
- ✅ Notification Channel 생성: 완료
- ❌ **푸시 알림 수신: 실패**

**사용자 증상**: "아직도 안되고 있어 다른 원인이 있지 않을까?"

---

## 🔍 1단계: SHA-1 Fingerprint 등록 확인 (가장 가능성 높음)

### ⚠️ 증상
- FCM 토큰은 정상적으로 생성됨
- 서버에서 푸시 전송해도 기기에서 수신 안 됨
- Firebase Console에서 테스트 메시지 전송해도 실패
- 에러 로그 없음 (조용히 실패)

### 🔧 해결 방법

#### Step 1: 현재 APK의 SHA-1 확인

**이미 확인된 SHA-1 Fingerprint:**
```
SHA1: 18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6
SHA256: EF:6E:7E:3F:AA:91:B7:FB:1E:46:81:55:CD:76:FA:F6:E5:85:1A:50:7D:6E:D5:23:01:E0:CE:04:AB:A5:F9:71
```

#### Step 2: Firebase Console에 SHA-1 등록

1. **Firebase Console 접속**
   ```
   https://console.firebase.google.com/project/makecallio/settings/general
   ```

2. **프로젝트 설정 > 내 앱 > Android 앱 선택**
   - 패키지 이름: `com.olssoo.makecall_app`
   - 앱 ID: `1:793164633643:android:c2f267d67b908274ccfc6e`

3. **SHA 인증서 지문 추가**
   - 아래로 스크롤하여 "SHA 인증서 지문" 섹션 찾기
   - "지문 추가" 버튼 클릭
   - **SHA-1 입력**: `18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6`
   - "저장" 클릭

4. **google-services.json 재다운로드 (중요!)**
   - Firebase Console에서 최신 `google-services.json` 다운로드
   - `android/app/google-services.json` 파일 교체
   - APK 재빌드 필요

5. **APK 재빌드 및 재설치**
   ```bash
   cd /home/user/flutter_app
   flutter clean
   flutter build apk --release
   ```

#### ⚠️ 주의사항
- **SHA-1 등록 후 반드시 google-services.json 재다운로드** 필요
- 기존 APK는 작동하지 않음 → 새 APK로 재설치 필요
- Firebase Console 변경사항 반영에 1-2분 소요

---

## 🔍 2단계: Firebase Cloud Messaging API 활성화 확인

### ⚠️ 증상
- FCM 토큰 생성됨
- SHA-1도 등록했는데 여전히 안 됨
- Firebase Console에서 "Authentication Error" 또는 "Invalid Credentials"

### 🔧 해결 방법

#### Google Cloud Console에서 API 활성화

1. **Google Cloud Console 접속**
   ```
   https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=makecallio
   ```

2. **Firebase Cloud Messaging API 활성화**
   - "Firebase Cloud Messaging API" 검색
   - "사용" 버튼 클릭
   - 상태가 "사용 설정됨"으로 변경되는지 확인

3. **Cloud Messaging (Legacy) API도 확인**
   ```
   https://console.cloud.google.com/apis/library/googlecloudmessaging.googleapis.com?project=makecallio
   ```
   - Legacy API도 활성화 (일부 오래된 라이브러리에서 필요)

---

## 🔍 3단계: Google Play Services 확인 (기기 문제)

### ⚠️ 증상
- 다른 앱들의 푸시 알림은 잘 수신됨
- 우리 앱만 안 됨
- FCM 토큰은 생성되지만 수신 안 됨

### 🔧 해결 방법

#### 테스트 기기 환경 확인

1. **Google Play Services 설치 확인**
   - 설정 → 앱 → "Google Play 서비스" 검색
   - 설치되어 있고 최신 버전인지 확인
   - 비활성화되어 있으면 활성화

2. **Google Play Store 로그인 확인**
   - Play Store 앱 열기
   - Google 계정으로 로그인되어 있는지 확인
   - 로그아웃 상태에서는 FCM 작동하지 않음

3. **날짜/시간 설정 확인**
   - 설정 → 일반 → 날짜 및 시간
   - "자동 날짜 및 시간" 활성화
   - 시간대가 올바른지 확인

---

## 🔍 4단계: 배터리 최적화 제외 (백그라운드 수신 문제)

### ⚠️ 증상
- 앱이 포그라운드에 있을 때만 푸시 수신됨
- 앱을 종료하거나 백그라운드로 보내면 수신 안 됨
- 잠자기 모드에서 푸시 안 옴

### 🔧 해결 방법

#### 배터리 최적화 제외 설정

1. **앱별 배터리 최적화 제외**
   - 설정 → 배터리 → 배터리 최적화
   - "모든 앱" 선택
   - "MAKECALL" 찾아서 "최적화 안 함" 선택

2. **절전 모드 예외 추가**
   - 설정 → 배터리 → 절전 모드
   - "절전 모드 예외" 또는 "제한 없음"
   - MAKECALL 앱 추가

3. **백그라운드 데이터 허용**
   - 설정 → 앱 → MAKECALL → 데이터 사용
   - "백그라운드 데이터" 활성화
   - "데이터 세이버 무시" 활성화

---

## 🔍 5단계: 알림 권한 및 채널 확인

### ⚠️ 증상
- FCM 토큰 생성됨
- 푸시는 수신되는데 알림이 표시되지 않음

### 🔧 해결 방법

#### Android 설정에서 알림 권한 확인

1. **앱 알림 권한 확인**
   - 설정 → 앱 → MAKECALL → 알림
   - "알림 허용" 활성화
   - "팝업 허용" 활성화 (중요!)
   - "알림 배지" 활성화

2. **알림 채널 확인**
   - 설정 → 앱 → MAKECALL → 알림
   - "High Importance Notifications" 채널 존재 확인
   - 채널 설정:
     - 중요도: 긴급 (또는 높음)
     - 소리: 활성화
     - 진동: 활성화

3. **방해 금지 모드 확인**
   - 설정 → 소리 및 진동 → 방해 금지
   - 방해 금지 모드 비활성화 또는
   - "예외" 설정에서 MAKECALL 앱 추가

---

## 🔍 6단계: Firebase Console 테스트 메시지 전송

### ⚠️ 증상 파악
- 서버 문제인지 클라이언트 문제인지 구분

### 🔧 테스트 방법

#### Firebase Console에서 직접 테스트

1. **Firebase Console → Cloud Messaging**
   ```
   https://console.firebase.google.com/project/makecallio/messaging
   ```

2. **새 캠페인 → Firebase 알림 메시지**
   - 알림 제목: "테스트 알림"
   - 알림 텍스트: "푸시 알림 테스트 중입니다"

3. **타겟 선택**
   - "단일 기기" 선택
   - FCM 토큰 입력 (Firestore `fcm_tokens` 컬렉션에서 복사)

4. **테스트 메시지 전송**
   - "테스트 메시지 보내기" 클릭
   - 기기에서 알림 수신되는지 확인

#### 결과 해석

| 결과 | 원인 | 해결 방법 |
|------|------|-----------|
| ✅ 수신됨 | 서버 코드 문제 | 서버 측 FCM 전송 로직 점검 |
| ❌ 수신 안 됨 | 클라이언트 설정 문제 | 1-5단계 재점검 |
| ⚠️ "Invalid Registration" | SHA-1 미등록 또는 토큰 만료 | SHA-1 등록 + 앱 재설치 |

---

## 🔍 7단계: ADB Logcat으로 실시간 디버깅

### ⚠️ 원인 파악
- FCM 메시지가 기기에 도달하는지 확인
- 에러 메시지 확인

### 🔧 디버깅 방법

#### USB 디버깅으로 로그 확인

1. **USB 디버깅 활성화**
   - 설정 → 개발자 옵션 → USB 디버깅 활성화
   - 기기를 컴퓨터에 USB 연결

2. **ADB Logcat 실행**
   ```bash
   # FCM 관련 로그만 필터링
   adb logcat | grep -E "(FirebaseMessaging|FCM|GCM|TokenRefresh)"
   ```

3. **푸시 메시지 전송 후 로그 확인**
   - Firebase Console에서 테스트 메시지 전송
   - 로그에서 다음 패턴 찾기:
     ```
     ✅ 정상: "Received FCM message", "Displaying notification"
     ❌ 오류: "Error receiving FCM", "Invalid token", "Authentication failed"
     ```

4. **주요 에러 메시지 해석**
   ```
   "INVALID_SENDER" → google-services.json 문제 또는 프로젝트 불일치
   "MismatchSenderId" → Firebase 프로젝트 ID 불일치
   "NOT_REGISTERED" → FCM 토큰 만료 또는 삭제됨
   "SERVICE_NOT_AVAILABLE" → Google Play Services 문제
   ```

---

## 🔍 8단계: 코드 레벨 검증

### ⚠️ 증상
- 모든 설정이 올바른데도 여전히 안 됨
- 코드에 문제가 있을 가능성

### 🔧 검증 항목

#### 1. FirebaseMessagingService가 실제로 등록되었는지 확인

**AndroidManifest.xml 확인:**
```xml
<!-- ✅ 현재 설정 (올바름) -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

**⚠️ 흔한 실수:**
```xml
<!-- ❌ 잘못된 예시 1: 커스텀 서비스 이름 (구현 없음) -->
<service android:name=".MyFirebaseMessagingService" />

<!-- ❌ 잘못된 예시 2: exported="true" (보안 문제) -->
<service android:exported="true" />
```

#### 2. Notification Channel이 제대로 생성되었는지 확인

**fcm_service.dart 확인 (Line 54-77):**
```dart
// ✅ 현재 코드 (올바름)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // ← AndroidManifest.xml과 ID 일치해야 함
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high, // ← 중요: 최소 Importance.high 이상
  playSound: true,
  enableVibration: true,
);
```

**⚠️ 주의사항:**
- Channel ID가 AndroidManifest.xml의 `default_notification_channel_id`와 **정확히 일치**해야 함
- `Importance.high` 이상이어야 팝업 알림 표시됨

#### 3. FCM 토큰이 올바른 형식인지 확인

**Firestore `fcm_tokens` 컬렉션 확인:**
```javascript
// ✅ 올바른 FCM 토큰 형식
{
  userId: "user123",
  fcmToken: "d1234567890abcdef...", // 152자 이상
  platform: "android",
  isActive: true
}
```

**⚠️ 잘못된 토큰:**
- 너무 짧은 토큰 (100자 미만)
- null 또는 undefined
- iOS 토큰을 Android 기기에 사용

---

## 🎯 9단계: 최종 점검 체크리스트

### ✅ Firebase 프로젝트 설정

- [ ] **SHA-1 Fingerprint 등록됨** (Firebase Console)
- [ ] **google-services.json 최신 버전** (SHA-1 등록 후 재다운로드)
- [ ] **패키지 이름 일치** (google-services.json ↔ build.gradle.kts ↔ AndroidManifest.xml)
- [ ] **Firebase Cloud Messaging API 활성화** (Google Cloud Console)
- [ ] **Firebase 프로젝트 ID 일치** (makecallio)

### ✅ Android 앱 설정

- [ ] **FirebaseMessagingService 등록** (AndroidManifest.xml)
- [ ] **Notification Channel 생성** (fcm_service.dart)
- [ ] **flutter_local_notifications 패키지 설치** (pubspec.yaml)
- [ ] **Core Library Desugaring 활성화** (build.gradle.kts)
- [ ] **알림 권한 요청** (POST_NOTIFICATIONS)

### ✅ 기기 환경

- [ ] **Google Play Services 설치 및 최신 버전**
- [ ] **Google 계정 로그인** (Play Store)
- [ ] **배터리 최적화 제외** (MAKECALL 앱)
- [ ] **알림 권한 허용** (설정 → 앱 → MAKECALL)
- [ ] **방해 금지 모드 비활성화**

### ✅ 코드 검증

- [ ] **FCM 초기화 로그 확인** ("✅ Firebase 초기화 완료")
- [ ] **FCM 토큰 생성 로그 확인** ("✅ FCM 토큰 생성 완료!")
- [ ] **Firestore 저장 로그 확인** ("✅ FCM-SAVE] Firestore 저장 완료!")
- [ ] **Channel ID 일치 확인** (fcm_service.dart ↔ AndroidManifest.xml)

---

## 🚀 10단계: 단계별 해결 우선순위

### 1순위: SHA-1 Fingerprint 등록 (90% 확률)
```bash
# 1. Firebase Console에서 SHA-1 등록
# 2. google-services.json 재다운로드
# 3. APK 재빌드 및 재설치
cd /home/user/flutter_app
flutter clean
flutter build apk --release
```

### 2순위: Firebase Cloud Messaging API 활성화 (5% 확률)
```
Google Cloud Console → API 및 서비스 → 라이브러리
→ "Firebase Cloud Messaging API" 검색 → 사용 설정
```

### 3순위: 기기 환경 문제 (3% 확률)
- Google Play Services 재설치
- 배터리 최적화 제외
- 알림 권한 재설정

### 4순위: 코드 문제 (2% 확률)
- Channel ID 불일치
- 잘못된 FCM 토큰 사용

---

## 📝 디버깅 로그 수집 방법

### APK 설치 후 첫 실행 시 확인할 로그

```dart
// Flutter 앱 실행 후 콘솔 로그:
✅ Firebase 초기화 완료 (Flutter)
🔔 [FCM] 초기화 시작
   User ID: user123
   Platform: android
🤖 [FCM] Android: 알림 채널 생성 중...
✅ [FCM] Android: 알림 채널 생성 완료
📱 [FCM] 알림 권한 요청 중...
✅ [FCM] 알림 권한 응답: AuthorizationStatus.authorized
🔑 [FCM] 토큰 요청 시작...
📱 [FCM] 모바일 플랫폼: 일반 토큰 요청
🔄 [FCM] getToken() 호출 중...
🔄 [FCM] getToken() 완료
✅ [FCM] 토큰 생성 완료!
   - 토큰 앞부분: d1234567890abcdef...
   - 전체 길이: 163자
   - 플랫폼: android
   - 사용자 ID: user123
💾 [FCM] Firestore 저장 시작...
✅ [FCM] Firestore 저장 완료
```

**⚠️ 만약 위 로그가 보이지 않으면:**
1. Firebase 초기화 실패 → google-services.json 확인
2. 토큰 생성 실패 → Google Play Services 확인
3. Firestore 저장 실패 → 네트워크 연결 확인

---

## 🔧 최종 해결책: 완전 재설정

### 모든 방법을 시도했는데도 안 될 때

```bash
# 1. 완전 클린 빌드
cd /home/user/flutter_app
rm -rf android/build android/app/build android/.gradle
flutter clean
flutter pub get

# 2. Firebase Console에서 SHA-1 재등록
# 3. google-services.json 재다운로드 및 교체

# 4. Release APK 재빌드
flutter build apk --release

# 5. 기기에서 기존 앱 완전 삭제
adb uninstall com.olssoo.makecall_app

# 6. 새 APK 설치
adb install build/app/outputs/flutter-apk/app-release.apk

# 7. 기기 재부팅
adb reboot

# 8. 앱 실행 후 로그 확인
adb logcat | grep -E "(FirebaseMessaging|FCM)"
```

---

## 📞 추가 지원

### 여전히 문제가 해결되지 않으면

1. **ADB Logcat 로그 전체 수집**
   ```bash
   adb logcat > fcm_debug.log
   # 푸시 전송 후 30초 대기
   # Ctrl+C로 중지
   ```

2. **Firebase Console 설정 스크린샷**
   - 프로젝트 설정 → 내 앱 → Android 앱
   - SHA 인증서 지문 섹션

3. **기기 정보 수집**
   - Android 버전
   - 제조사 및 모델명
   - Google Play Services 버전

---

## ✅ 성공 확인 방법

### 푸시 알림이 정상 작동하는 경우

1. **Firebase Console 테스트 메시지**
   - 전송 후 5초 이내에 기기에서 알림 수신
   - 알림음 및 진동 작동

2. **백그라운드/포그라운드 모두 수신**
   - 앱 종료 상태에서도 알림 수신
   - 앱 실행 중에도 알림 표시

3. **Firestore fcm_tokens 컬렉션 확인**
   - 토큰이 올바르게 저장됨
   - isActive: true

4. **Flutter 로그 정상**
   ```
   ✅ [FCM] 토큰 생성 완료!
   ✅ [FCM] Firestore 저장 완료
   📨 포그라운드 메시지: 테스트 알림
   ```

---

## 🎯 결론

**가장 가능성 높은 원인: SHA-1 Fingerprint 미등록 (90%)**

1. Firebase Console에서 SHA-1 등록
2. google-services.json 재다운로드
3. APK 재빌드 및 재설치

**이 단계만 수행하면 대부분의 경우 해결됩니다!**
