# FCM 웹푸시 빠른 시작 가이드 🚀

## 5분 안에 웹푸시 활성화하기

### Step 1: VAPID 키 생성 (2분)

1. 🔗 Firebase Console 접속: https://console.firebase.google.com/
2. `makecallio` 프로젝트 선택
3. ⚙️ **Project Settings** → **Cloud Messaging** 탭
4. 🔑 **Web Push certificates** → **Generate key pair**
5. 📋 생성된 키 복사

### Step 2: VAPID 키 적용 (1분)

📄 `/lib/services/fcm_service.dart` 파일 열기

```dart
// 라인 53-60 근처 찾기
if (kIsWeb) {
  const vapidKey = 'YOUR_VAPID_KEY_HERE'; // ← 여기에 복사한 키 붙여넣기
  
  try {
    _fcmToken = await _messaging.getToken(vapidKey: vapidKey);
```

**저장 후 앱 재빌드 필수!**

### Step 3: 웹푸시 활성화 (1분)

1. 🌐 웹 브라우저에서 MakeCall 앱 열기
2. 👤 우측 상단 프로필 아이콘 클릭
3. 🔔 **알림 설정** → **웹 푸시 알림 활성화** 클릭
4. ✅ 브라우저 알림 권한 허용
5. 🎉 활성화 완료 메시지 확인!

### Step 4: 테스트 (1분)

#### Firebase Console에서 테스트
1. Firebase Console → **Messaging**
2. **Send test message**
3. FCM 토큰 입력 (브라우저 콘솔에 출력됨)
4. **Test** 버튼 클릭
5. 🔔 알림 수신 확인!

---

## 🎯 빠른 문제 해결

### ❌ 토큰을 가져올 수 없습니다
→ VAPID 키 설정 확인 및 앱 재빌드

### ❌ 알림 권한이 거부되었습니다
→ 브라우저 설정에서 알림 허용

### ❌ 서비스 워커 오류
→ HTTPS 연결 확인 (localhost는 OK)

---

## 📚 상세 가이드

전체 문서: [FCM_WEB_PUSH_GUIDE.md](./FCM_WEB_PUSH_GUIDE.md)

---

## ✅ 체크리스트

- [ ] Firebase Console에서 VAPID 키 생성
- [ ] `fcm_service.dart`에 VAPID 키 적용
- [ ] Flutter 앱 재빌드 (`flutter build web --release`)
- [ ] 브라우저에서 웹푸시 활성화
- [ ] 브라우저 알림 권한 허용
- [ ] Firebase Console에서 테스트 메시지 전송
- [ ] 알림 수신 확인

---

**🎉 완료! 이제 웹 브라우저에서도 실시간 알림을 받을 수 있습니다!**
