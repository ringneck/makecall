# GoogleService-Info.plist 추가 방법

## 🚀 빠른 방법 (권장)

### 파일을 여기에 업로드해주세요!

이미 GoogleService-Info.plist 파일을 가지고 계신다면:
1. 이 채팅에 파일 업로드
2. 자동으로 프로젝트에 추가됩니다
3. Xcode에서 확인만 하면 완료!

---

## 📥 수동 추가 방법 (Xcode 사용)

### 1단계: Xcode에서 프로젝트 열기
```bash
cd /home/user/flutter_app
open ios/Runner.xcworkspace
```

### 2단계: 파일 추가하기

**방법 A: 드래그 앤 드롭**
1. Finder에서 다운로드한 `GoogleService-Info.plist` 찾기
2. Xcode의 **Runner 폴더**로 드래그
3. 팝업 창에서 다음 항목 확인:
   - ✅ **"Copy items if needed"** 체크
   - ✅ **"Add to targets: Runner"** 체크
4. **"Finish"** 클릭

**방법 B: 메뉴에서 추가**
1. Xcode에서 **Runner** 폴더 선택
2. 메뉴: **File** → **Add Files to "Runner"...**
3. GoogleService-Info.plist 선택
4. 옵션 확인:
   - ✅ **"Copy items if needed"** 체크
   - ✅ **"Add to targets: Runner"** 체크
5. **"Add"** 클릭

### 3단계: 파일 위치 확인

**Project Navigator에서 확인:**
```
Runner
├── AppDelegate.swift
├── Info.plist
├── GoogleService-Info.plist  ← 이 파일이 보여야 함
├── Assets.xcassets
└── ...
```

**파일 경로:**
```
/home/user/flutter_app/ios/Runner/GoogleService-Info.plist
```

### 4단계: Target Membership 확인

1. GoogleService-Info.plist 파일 클릭
2. 오른쪽 패널에서 **"File Inspector"** 탭 (📄 아이콘)
3. **"Target Membership"** 섹션에서:
   - ✅ **Runner** 체크되어 있어야 함

### 5단계: 파일 내용 확인 (선택)

GoogleService-Info.plist를 클릭하면 다음과 같은 내용이 보여야 합니다:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CLIENT_ID</key>
    <string>123456789-abcdefghijk.apps.googleusercontent.com</string>
    
    <key>REVERSED_CLIENT_ID</key>
    <string>com.googleusercontent.apps.123456789-abcdefghijk</string>
    
    <key>API_KEY</key>
    <string>AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz</string>
    
    <key>GCM_SENDER_ID</key>
    <string>123456789012</string>
    
    <key>PROJECT_ID</key>
    <string>your-project-id</string>
    
    <key>STORAGE_BUCKET</key>
    <string>your-project-id.appspot.com</string>
    
    <key>IS_ADS_ENABLED</key>
    <false/>
    
    <key>IS_ANALYTICS_ENABLED</key>
    <false/>
    
    <key>IS_APPINVITE_ENABLED</key>
    <true/>
    
    <key>IS_GCM_ENABLED</key>
    <true/>
    
    <key>IS_SIGNIN_ENABLED</key>
    <true/>
    
    <key>GOOGLE_APP_ID</key>
    <string>1:123456789012:ios:abcdef1234567890</string>
</dict>
</plist>
```

---

## ✅ 완료 후 확인

### 1. Clean Build Folder
```
Xcode 메뉴: Product → Clean Build Folder
단축키: Cmd + Shift + K
```

### 2. 앱 재빌드
```
실제 iOS 기기 선택
실행: Cmd + R
```

### 3. 로그인 후 콘솔 확인

**예상 로그 (성공):**
```
✅ APNs 토큰 수신: 1234567890abcdef...
🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...
🔔 [FCM] 초기화 시작
📱 [FCM] 알림 권한 요청 중...
✅ [FCM] 알림 권한 응답: authorized
🍎 [FCM] iOS: APNs 토큰 확인 중...
✅ [FCM] APNs 토큰 존재: 1234567890abcdef...
🔄 [FCM] getToken() 호출 중...
🔄 [FCM] getToken() 완료
✅ [FCM] 토큰 생성 완료!
💾 [FCM-SAVE] Firestore 저장 완료!
```

**오류 없음 (성공):**
```
❌ nw_endpoint_flow_failed_with_error 오류 사라짐
```

### 4. Firestore 확인

Firebase Console → Firestore Database → fcm_tokens 컬렉션
```
문서 ID: {userId}_{deviceId}
예시: abc123_ios_iPhone15Pro

필드:
├── userId: "abc123..."
├── fcmToken: "dGhpc2lzYWZha2V0b2s..."
├── deviceId: "ios_iPhone15Pro"
├── deviceName: "iPhone 15 Pro (iOS 17.4)"
├── platform: "ios"
├── createdAt: Timestamp
├── lastActiveAt: Timestamp
└── isActive: true
```

---

## ⚠️ 주의사항

### Bundle Identifier 일치 확인

**Firebase Console의 Bundle ID와 Xcode의 Bundle Identifier가 정확히 일치해야 합니다!**

**확인 방법:**
1. **Firebase Console:**
   ```
   프로젝트 설정 → 일반 탭 → iOS 앱 → 번들 ID
   예시: com.makecall.app
   ```

2. **Xcode:**
   ```
   Runner 프로젝트 선택 → Signing & Capabilities → Bundle Identifier
   예시: com.makecall.app
   ```

3. **일치하지 않으면:**
   - Firebase에서 새 iOS 앱 추가 (올바른 Bundle ID로)
   - 또는 Xcode에서 Bundle Identifier 변경

### 보안 주의사항

```
⚠️ GoogleService-Info.plist는 민감한 정보를 포함합니다!
- API 키
- 프로젝트 ID
- 클라이언트 ID

✅ .gitignore에 추가됨 (자동)
❌ 공개 저장소에 업로드 금지
❌ 스크린샷 공유 시 내용 가리기
```

---

## 🆘 문제 해결

### 문제: "File not found: GoogleService-Info.plist"

**원인:** 파일이 올바른 위치에 없거나 Target Membership이 체크되지 않음

**해결:**
1. Xcode에서 파일 위치 확인: Runner 폴더 아래에 있어야 함
2. 파일 선택 → File Inspector → Target Membership에서 Runner 체크
3. 파일 삭제 후 다시 추가 ("Copy items if needed" 체크 확인)

### 문제: "FCM token still not generated"

**원인:** GoogleService-Info.plist 내용 오류 또는 Bundle ID 불일치

**해결:**
1. GoogleService-Info.plist 내용 확인 (위의 예시 참조)
2. Bundle ID 일치 확인 (Firebase Console ↔ Xcode)
3. Firebase Console에서 파일 재다운로드
4. Clean Build Folder (Cmd + Shift + K)
5. 앱 삭제 후 재설치

### 문제: 여전히 네트워크 오류 발생

**원인:** 
1. 파일이 Target Membership에 포함되지 않음
2. Bundle ID 불일치
3. 네트워크 연결 문제

**해결:**
1. Target Membership 다시 확인
2. Bundle ID 정확히 일치시키기
3. Wi-Fi/셀룰러 네트워크 확인
4. VPN 끄고 테스트
5. Firebase 프로젝트 상태 확인 (Console에서)

---

## 📞 추가 지원

문제가 계속되면 다음 정보를 공유해주세요:

1. **Xcode Project Navigator 스크린샷**
   - Runner 폴더 구조
   - GoogleService-Info.plist 위치 확인

2. **Target Membership 스크린샷**
   - GoogleService-Info.plist 선택 시 오른쪽 패널

3. **Bundle Identifier**
   - Xcode의 Bundle Identifier
   - Firebase Console의 Bundle ID

4. **콘솔 로그**
   - 전체 FCM 초기화 로그
   - 오류 메시지

5. **Firebase Console 스크린샷**
   - 프로젝트 설정 → 일반 → iOS 앱 섹션
