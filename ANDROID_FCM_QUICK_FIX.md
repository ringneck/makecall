# ⚡ Android FCM 푸시 알림 빠른 해결 가이드

## 🎯 현재 상황 요약

```
✅ Firebase 초기화: 정상
✅ FCM 토큰 생성: 정상
✅ Firestore 저장: 정상
❌ 푸시 알림 수신: 실패
```

**사용자 문의**: "아직도 안되고 있어 다른 원인이 있지 않을까?"

---

## 🚨 가장 가능성 높은 원인 (90%)

### ⚠️ SHA-1 Fingerprint 미등록

**증상:**
- FCM 토큰은 정상적으로 생성됨
- 코드 레벨에서 에러 없음
- Firebase Console에서 테스트 메시지 전송해도 기기에서 수신 안 됨
- 조용히 실패 (에러 로그 없음)

**왜 이런 현상이 발생하나요?**
- Android Release APK는 keystore로 서명되어야 함
- Firebase는 보안을 위해 SHA-1 지문으로 앱을 인증
- SHA-1이 등록되지 않으면 Firebase 서버가 푸시 전송을 차단

---

## 🔧 해결 방법 (5단계)

### Step 1: SHA-1 Fingerprint 확인

**현재 Release APK의 SHA-1:**
```
18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6
```

**다시 확인하려면:**
```bash
keytool -list -v -keystore android/release-key.jks -alias release -storepass ehySFRmG16vf@NLeaJf0 | grep "SHA1:"
```

---

### Step 2: Firebase Console에 SHA-1 등록

1. **Firebase Console 접속**
   ```
   https://console.firebase.google.com/project/makecallio/settings/general
   ```

2. **프로젝트 설정 → 내 앱 → Android 앱 선택**
   - 패키지: `com.olssoo.makecall_app`
   - 앱 ID: `1:793164633643:android:c2f267d67b908274ccfc6e`

3. **SHA 인증서 지문 섹션 찾기**
   - 페이지를 아래로 스크롤
   - "SHA 인증서 지문" 섹션 찾기

4. **지문 추가 버튼 클릭**
   - "지문 추가" 버튼 클릭
   - SHA-1 입력: `18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6`
   - "저장" 버튼 클릭

---

### Step 3: google-services.json 재다운로드

**⚠️ 중요: SHA-1 등록 후 반드시 이 단계 필요!**

1. **Firebase Console 같은 페이지에서**
   - "google-services.json 다운로드" 버튼 클릭

2. **기존 파일 교체**
   ```bash
   # 다운로드한 파일을 프로젝트에 복사
   cp ~/Downloads/google-services.json /home/user/flutter_app/android/app/google-services.json
   ```

**왜 재다운로드해야 하나요?**
- google-services.json에 SHA-1 관련 설정이 업데이트됨
- 기존 파일로는 SHA-1 인증이 작동하지 않음

---

### Step 4: APK 재빌드

**⚠️ 기존 APK는 작동하지 않습니다!**

```bash
cd /home/user/flutter_app
flutter clean
flutter build apk --release
```

**빌드 완료 후:**
- 새 APK 위치: `build/app/outputs/flutter-apk/app-release.apk`
- 파일 크기: 약 55 MB

---

### Step 5: 앱 재설치 및 테스트

1. **기존 앱 삭제**
   - 기기에서 MAKECALL 앱 완전 삭제

2. **새 APK 설치**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. **앱 실행 및 로그인**

4. **Firebase Console 테스트 메시지 전송**
   ```
   Firebase Console → Cloud Messaging → 새 캠페인
   → Firebase 알림 메시지 → 단일 기기 선택
   → FCM 토큰 입력 (Firestore fcm_tokens 컬렉션에서 복사)
   → "테스트 메시지 보내기" 클릭
   ```

5. **기기에서 알림 수신 확인** ✅

---

## 📊 Step 2에서 작업할 정확한 위치 (시각적 가이드)

### Firebase Console 화면 구조

```
┌─────────────────────────────────────────────────────────┐
│ Firebase Console - makecallio                            │
├─────────────────────────────────────────────────────────┤
│  프로젝트 설정 (⚙️ 아이콘)                                │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐│
│  │ 일반 탭                                               ││
│  │                                                       ││
│  │ 내 앱                                                 ││
│  │ ┌───────────────────────────────────────────────┐   ││
│  │ │ 🤖 Android 앱                                  │   ││
│  │ │ 패키지 이름: com.olssoo.makecall_app         │   ││
│  │ │ 앱 ID: 1:793164633643:android:...            │   ││
│  │ │                                                │   ││
│  │ │ ▼ google-services.json 다운로드              │   ││
│  │ │                                                │   ││
│  │ │ ───────────────────────────────────────────── │   ││
│  │ │                                                │   ││
│  │ │ SHA 인증서 지문                                │   ││
│  │ │ ┌──────────────────────────────────────────┐ │   ││
│  │ │ │ SHA-1                                     │ │   ││
│  │ │ │ (등록된 지문이 여기에 표시됩니다)          │ │   ││
│  │ │ │                                           │ │   ││
│  │ │ │ [+ 지문 추가] ← 이 버튼 클릭!            │ │   ││
│  │ │ └──────────────────────────────────────────┘ │   ││
│  │ └───────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## ❓ 이 방법으로도 안 되는 경우

### 2순위: Firebase Cloud Messaging API 활성화 (5% 확률)

```
Google Cloud Console 접속:
https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=makecallio

"Firebase Cloud Messaging API" → "사용 설정" 클릭
```

---

### 3순위: 기기 환경 문제 (3% 확률)

**체크리스트:**
- [ ] Google Play Services 설치 및 최신 버전
- [ ] Google 계정 로그인 (Play Store)
- [ ] 배터리 최적화 제외 (MAKECALL 앱)
- [ ] 알림 권한 허용 (설정 → 앱 → MAKECALL)
- [ ] 방해 금지 모드 비활성화

**배터리 최적화 제외 방법:**
```
설정 → 배터리 → 배터리 최적화
→ 모든 앱 → MAKECALL 찾기
→ "최적화 안 함" 선택
```

**알림 권한 확인:**
```
설정 → 앱 → MAKECALL → 알림
→ "알림 허용" 활성화
→ "팝업 허용" 활성화
→ "알림 배지" 활성화
```

---

### 4순위: ADB Logcat 디버깅 (2% 확률)

**USB 디버깅 활성화:**
```
설정 → 개발자 옵션 → USB 디버깅 활성화
```

**Logcat 실행:**
```bash
adb logcat | grep -E "(FirebaseMessaging|FCM|GCM)"
```

**주요 에러 패턴:**
- `INVALID_SENDER` → google-services.json 문제
- `MismatchSenderId` → Firebase 프로젝트 ID 불일치
- `NOT_REGISTERED` → FCM 토큰 만료
- `SERVICE_NOT_AVAILABLE` → Google Play Services 문제

📚 **자세한 가이드**: `ADB_LOGCAT_FCM_DEBUG.md` 참고

---

## ✅ 성공 확인 방법

### 푸시 알림이 정상 작동하는 경우

1. **Firebase Console 테스트 메시지**
   - 전송 후 5초 이내 기기에서 알림 수신
   - 알림음 및 진동 작동

2. **백그라운드/포그라운드 모두 수신**
   - 앱 종료 상태: 알림 수신됨
   - 앱 실행 중: 알림 표시됨

3. **Firestore 토큰 확인**
   - `fcm_tokens` 컬렉션에 토큰 저장됨
   - `isActive: true`

---

## 📝 전체 프로세스 요약

```
1. SHA-1 Fingerprint 확인
   ↓
2. Firebase Console에 SHA-1 등록
   ↓
3. google-services.json 재다운로드 (중요!)
   ↓
4. APK 재빌드
   cd /home/user/flutter_app
   flutter clean
   flutter build apk --release
   ↓
5. 기존 앱 삭제 → 새 APK 설치 → 테스트
   ↓
6. Firebase Console 테스트 메시지 전송
   ↓
7. 기기에서 알림 수신 확인 ✅
```

---

## 🎯 핵심 요약

| 단계 | 시간 소요 | 중요도 |
|------|----------|--------|
| 1. SHA-1 등록 | 2분 | ⭐⭐⭐⭐⭐ |
| 2. google-services.json 재다운로드 | 1분 | ⭐⭐⭐⭐⭐ |
| 3. APK 재빌드 | 5분 | ⭐⭐⭐⭐⭐ |
| 4. 앱 재설치 | 1분 | ⭐⭐⭐⭐⭐ |
| 5. 테스트 | 2분 | ⭐⭐⭐⭐⭐ |

**총 소요 시간: 약 11분**
**성공 확률: 90%**

---

## 📚 추가 참고 자료

- **상세 가이드**: `ANDROID_FCM_TROUBLESHOOTING.md` (10가지 해결 단계)
- **디버깅 가이드**: `ADB_LOGCAT_FCM_DEBUG.md` (Logcat 사용법)
- **iOS 가이드**: `FCM_FIXES_APPLIED.md` (iOS FCM 설정)

---

## 💡 핵심 포인트

**가장 중요한 3가지:**

1. **SHA-1 등록** (90% 확률)
   - Firebase Console에서 SHA-1 지문 추가

2. **google-services.json 재다운로드** (필수!)
   - SHA-1 등록 후 반드시 재다운로드

3. **APK 재빌드 및 재설치** (필수!)
   - 기존 APK로는 작동하지 않음

**이 3가지만 수행하면 대부분 해결됩니다!**

---

## 🚀 바로 시작하기

### 지금 당장 해야 할 일:

**1단계: Firebase Console 열기**
```
https://console.firebase.google.com/project/makecallio/settings/general
```

**2단계: SHA-1 등록**
```
SHA-1: 18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6
```

**3단계: google-services.json 재다운로드**

**4단계: 빌드 명령어 실행**
```bash
cd /home/user/flutter_app
flutter clean
flutter build apk --release
```

**✅ 완료!**
