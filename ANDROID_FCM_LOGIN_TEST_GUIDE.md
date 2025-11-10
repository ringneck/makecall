# 📱 Android FCM 로그인 후 테스트 가이드

## 🎯 현재 상황 분석

### ✅ 확인된 사항
- **FCM 코드**: 정상 구현됨
- **로그인 시 FCM 초기화**: auth_service.dart의 signIn() 함수에서 자동 실행
- **현재 앱 상태**: 로그아웃 상태 (정상)

### ❓ FCM 로그가 없는 이유
**로그인하지 않아서 FCM 초기화가 실행되지 않은 것**입니다. 이는 **정상적인 동작**입니다.

---

## 📝 로그인 시 FCM 초기화 코드 확인

### auth_service.dart (Line 260-283)
```dart
// FCM 초기화 (로그인 성공 후)
try {
  print('');
  print('🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...');
  print('   User ID: ${credential.user!.uid}');
  print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
  
  final fcmService = FCMService();
  await fcmService.initialize(credential.user!.uid);
  
  print('✅ [AUTH] FCM 초기화 완료');
} catch (e, stackTrace) {
  print('❌ [AUTH] FCM 초기화 오류: $e');
  print('Stack trace:');
  print(stackTrace);
}
```

**📌 핵심**: 로그인이 성공하면 **자동으로 FCM 초기화가 실행**됩니다.

---

## 🧪 올바른 테스트 절차

### 1단계: ADB Logcat 준비 (터미널 1)
```bash
# 실시간 FCM 로그 모니터링
adb logcat | grep -E "(FCM|FirebaseMessaging|firebase|AUTH)"
```

### 2단계: 앱에서 로그인 수행
1. MAKECALL 앱 실행
2. 사용자 ID/PW 입력
3. **로그인 버튼 클릭**

### 3단계: 로그인 직후 예상 로그 확인

```
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
I/flutter:    User ID: [사용자UID]
I/flutter:    Platform: Mobile
I/flutter: 🔔 [FCM] 초기화 시작
I/flutter:    User ID: [사용자UID]
I/flutter:    Platform: android
I/flutter: 🤖 [FCM] Android: 알림 채널 생성 중...
I/flutter: ✅ [FCM] Android: 알림 채널 생성 완료
I/flutter: 📱 [FCM] 알림 권한 요청 중...
I/flutter: ✅ [FCM] 알림 권한 응답: AuthorizationStatus.authorized
I/flutter: 🔑 [FCM] 토큰 요청 시작...
I/flutter: 📱 [FCM] 모바일 플랫폼: 일반 토큰 요청
I/flutter: 🔄 [FCM] getToken() 호출 중...
I/flutter: 🔄 [FCM] getToken() 완료
I/flutter: ✅ [FCM] 토큰 생성 완료!
I/flutter:    - 토큰 앞부분: d1234567890abcdef...
I/flutter:    - 전체 길이: 163자
I/flutter:    - 플랫폼: android
I/flutter:    - 사용자 ID: [사용자UID]
I/flutter: 💾 [FCM] Firestore 저장 시작...
I/flutter: ✅ [FCM] Firestore 저장 완료
I/flutter:    - 컬렉션: fcm_tokens
I/flutter:    - 문서 ID: [userId]_[deviceId]
I/flutter: ✅ [AUTH] FCM 초기화 완료
```

---

## 🔍 로그 분석 시나리오

### ✅ 시나리오 1: 정상 작동 (예상)
```
로그인 클릭
  ↓
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
  ↓
I/flutter: 🔔 [FCM] 초기화 시작
  ↓
I/flutter: ✅ [FCM] 토큰 생성 완료!
  ↓
I/flutter: ✅ [FCM] Firestore 저장 완료
  ↓
I/flutter: ✅ [AUTH] FCM 초기화 완료
```

**결과**: FCM 정상 작동! 🎉

---

### ⚠️ 시나리오 2: 로그인 성공했으나 FCM 로그 없음
```
로그인 클릭
  ↓
(로그인 성공)
  ↓
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...  ← 여기까지만 나옴
  ↓
(FCM 로그 없음)
```

**원인**: Firebase 초기화 문제 또는 google-services.json 문제

**해결 방법**:
1. SHA-1 등록 확인
2. google-services.json 재다운로드
3. APK 재빌드

---

### ❌ 시나리오 3: Firebase 에러 로그
```
I/flutter: 🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
I/flutter: ❌ [AUTH] FCM 초기화 오류: [에러 메시지]
```

**원인**: google-services.json 문제, SHA-1 미등록

**해결 방법**:
1. 에러 메시지 확인
2. ANDROID_FCM_TROUBLESHOOTING.md 참고
3. SHA-1 등록 후 APK 재빌드

---

## 🔑 Firebase Console 테스트 (로그인 후)

### 1단계: Firestore에서 FCM 토큰 확인
```
Firebase Console → Firestore Database → fcm_tokens 컬렉션
→ 사용자의 FCM 토큰 문서 확인
```

**예상 구조**:
```json
{
  "userId": "[사용자UID]",
  "fcmToken": "d1234567890abcdef...",
  "deviceId": "[기기ID]",
  "deviceName": "Samsung Galaxy S21",
  "platform": "android",
  "isActive": true,
  "createdAt": "2025-11-10T14:30:00.000Z",
  "lastActiveAt": "2025-11-10T14:30:00.000Z"
}
```

### 2단계: Firebase Console에서 테스트 메시지 전송
```
Firebase Console → Cloud Messaging → 새 캠페인
→ Firebase 알림 메시지
→ 알림 제목: "테스트 알림"
→ 알림 텍스트: "푸시 알림 테스트 중입니다"
→ 타겟: 단일 기기
→ FCM 토큰 입력 (Firestore에서 복사)
→ "테스트 메시지 보내기" 클릭
```

### 3단계: 기기에서 알림 수신 확인
- ✅ 정상: 기기에서 알림 수신 (소리 및 진동)
- ❌ 실패: 알림 수신 안 됨 → SHA-1 등록 필요

---

## 🚨 SHA-1 등록이 필요한 경우

### 증상
```
✅ FCM 토큰 생성: 정상
✅ Firestore 저장: 정상
✅ Firebase Console 테스트 메시지 전송: 성공
❌ 기기에서 알림 수신: 실패 (조용히 실패, 에러 로그 없음)
```

### 원인
- Android Release APK는 keystore로 서명됨
- Firebase는 SHA-1 지문으로 앱 인증
- **SHA-1 미등록 시 Firebase 서버가 푸시 전송 차단**

### 해결 방법
1. **Firebase Console 접속**:
   https://console.firebase.google.com/project/makecallio/settings/general

2. **SHA-1 등록**:
   ```
   18:1E:C9:0F:BC:D1:FD:04:38:0F:E1:7A:6F:8D:B3:29:20:CC:AC:A6
   ```

3. **google-services.json 재다운로드**

4. **APK 재빌드**:
   ```bash
   cd /home/user/flutter_app
   flutter clean
   flutter build apk --release
   ```

5. **기기에 재설치 및 재테스트**

---

## 📊 체크리스트

### ✅ 로그인 전 확인사항
- [ ] ADB logcat 실행 중
- [ ] 필터: `grep -E "(FCM|FirebaseMessaging|AUTH)"`
- [ ] 기기 USB 연결 확인

### ✅ 로그인 후 확인사항
- [ ] "🔔 [AUTH] 로그인 성공 - FCM 초기화 시작..." 로그 출력
- [ ] "🔔 [FCM] 초기화 시작" 로그 출력
- [ ] "✅ [FCM] 토큰 생성 완료!" 로그 출력
- [ ] "✅ [FCM] Firestore 저장 완료" 로그 출력
- [ ] "✅ [AUTH] FCM 초기화 완료" 로그 출력

### ✅ Firestore 확인사항
- [ ] fcm_tokens 컬렉션에 토큰 저장됨
- [ ] userId 필드 존재
- [ ] fcmToken 필드 존재 (163자 정도)
- [ ] platform 필드: "android"
- [ ] isActive 필드: true

### ✅ 푸시 테스트 확인사항
- [ ] Firebase Console 테스트 메시지 전송
- [ ] 기기에서 알림 수신됨
- [ ] 알림음 및 진동 작동

---

## 🎯 결론

### 현재 상태
**로그아웃 상태이므로 FCM 로그가 없는 것은 정상입니다.**

### 다음 단계
1. **로그인 수행** (가장 중요!)
2. **로그인 직후 FCM 로그 확인**
3. **Firestore에 토큰 저장 확인**
4. **Firebase Console 테스트 메시지 전송**
5. **알림 수신 확인**

### 예상 결과
- ✅ **90% 확률**: 로그인 후 FCM 정상 작동
- ⚠️ **10% 확률**: SHA-1 등록 필요 (Firebase Console 테스트 실패 시)

---

## 📞 추가 지원

로그인 후에도 FCM 로그가 안 나오는 경우:
1. **전체 로그 수집**: `adb logcat > fcm_login_test.log`
2. **Firebase 초기화 로그 확인**
3. **google-services.json 파일 확인**
4. **SHA-1 등록 상태 확인**

📚 **참고 문서**:
- ANDROID_FCM_QUICK_FIX.md (빠른 해결)
- ANDROID_FCM_TROUBLESHOOTING.md (완전 가이드)
- ADB_LOGCAT_FCM_DEBUG.md (디버깅 가이드)

---

**💡 핵심 요점**: 로그인만 하면 FCM 초기화가 자동으로 실행됩니다! 🚀
