# 📱 iOS APN 로그 확인 가이드

## 🔍 문제: APN 관련 로그가 출력되지 않음

APN 관련 로그가 전혀 출력되지 않는다면, 다음 사항들을 확인해야 합니다.

---

## ✅ 1단계: 올바른 로그 확인 위치

### A. Xcode Console에서 로그 확인

#### 방법 1: Xcode에서 직접 실행 (권장)
```bash
1. Xcode 열기
2. flutter_app/ios/Runner.xcworkspace 파일 더블클릭
3. 실제 iOS 기기 연결 (시뮬레이터는 APNs 미지원)
4. 상단에서 기기 선택
5. Cmd + R (Run) 눌러 앱 실행
6. 하단 Console 창에서 로그 확인
```

**예상 로그 출력:**
```
================================================================================
🚀 AppDelegate.application() 실행 시작
================================================================================

================================================================================
📊 iOS 환경 정보
================================================================================
iOS 버전: 17.2
기기 모델: iPhone
기기 이름: John's iPhone
✅ 실행 환경: 실제 iOS 기기
   → APNs 토큰 획득 가능
================================================================================

🔥 Firebase 초기화 중...
✅ Firebase 초기화 완료

📱 Flutter 플러그인 등록 중...
✅ Flutter 플러그인 등록 완료

🔔 iOS 알림 권한 요청 중...
✅ 알림 권한 요청 완료

🍎 APNs 원격 알림 등록 시작...
✅ APNs 등록 요청 전송 완료
   → didRegisterForRemoteNotificationsWithDeviceToken() 또는
   → didFailToRegisterForRemoteNotificationsWithError() 호출 대기 중...

🔥 Firebase Messaging 델리게이트 설정 중...
✅ Firebase Messaging 델리게이트 설정 완료

================================================================================
✅ AppDelegate.application() 실행 완료
================================================================================
```

#### 방법 2: Flutter 명령어로 실행
```bash
# 터미널에서
cd ~/makecall/flutter_app
flutter run -d <DEVICE_ID>

# 기기 ID 확인
flutter devices
```

**⚠️ 주의**: Flutter run으로 실행하면 Flutter 로그에 섞여서 보일 수 있습니다.

---

### B. 시뮬레이터에서 실행 시 예상 로그

**시뮬레이터에서 실행하면:**
```
================================================================================
📊 iOS 환경 정보
================================================================================
iOS 버전: 17.2
기기 모델: iPhone
기기 이름: iPhone 15 Pro
⚠️ 실행 환경: iOS 시뮬레이터
   → 시뮬레이터는 APNs를 지원하지 않습니다!
   → 실제 iOS 기기에서 테스트하세요.
================================================================================

... (Firebase 초기화 등은 정상) ...

🍎 APNs 원격 알림 등록 시작...
✅ APNs 등록 요청 전송 완료

❌ APNs 토큰 수신 실패
오류: APNS device token not set before retrieving FCM Token for Sender ID...
```

**→ 시뮬레이터에서는 절대 APNs 토큰을 받을 수 없습니다!**

---

## ✅ 2단계: 로그가 전혀 안 나오는 경우

### 경우 1: AppDelegate.swift 파일이 실행되지 않음

**확인 방법:**
```swift
// AppDelegate.swift의 첫 줄에서부터 로그가 출력되는지 확인

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(...) -> Bool {
    print("================================================================================")
    print("🚀 AppDelegate.application() 실행 시작")  // ← 이 로그가 보이나요?
    print("================================================================================")
    ...
  }
}
```

**해결 방법:**
1. Xcode에서 Clean Build Folder (Cmd+Shift+K)
2. DerivedData 삭제:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. CocoaPods 재설치:
   ```bash
   cd ios
   pod deintegrate
   pod install
   ```
4. Xcode 재시작 후 다시 빌드

---

### 경우 2: 잘못된 Build Configuration

**확인 사항:**
1. Xcode → Product → Scheme → Edit Scheme
2. Run → Info → Build Configuration → **Debug** 확인
3. Run → Options → Console → **Use Console** 체크 확인

---

### 경우 3: Firebase 초기화 실패

**증상:**
- "Firebase 초기화 중..." 로그 후 앱 크래시
- 또는 Firebase 관련 오류 메시지

**해결 방법:**
1. `GoogleService-Info.plist` 파일 확인:
   ```bash
   ls -la ios/Runner/GoogleService-Info.plist
   ```

2. 파일이 없다면:
   - Firebase Console에서 다운로드
   - Xcode에서 Runner 폴더에 추가 (Copy items if needed 체크)

3. Bundle Identifier 확인:
   - Xcode → Runner → Signing & Capabilities
   - Bundle Identifier가 GoogleService-Info.plist의 BUNDLE_ID와 일치하는지 확인

---

## ✅ 3단계: APNs 토큰 수신 실패 시

### A. 실제 기기에서 실패하는 경우

**증상:**
```
🍎 APNs 원격 알림 등록 시작...
✅ APNs 등록 요청 전송 완료

❌ APNs 토큰 수신 실패
오류: ...
```

**해결 방법:**

#### 1. Xcode Capabilities 확인
```
Xcode → Runner → Signing & Capabilities

✅ Push Notifications 추가되어 있는지 확인
✅ Background Modes 추가되어 있는지 확인
   └─ ✅ Remote notifications 체크

추가 방법:
1. "+ Capability" 버튼 클릭
2. "Push Notifications" 검색 후 추가
3. "Background Modes" 검색 후 추가
4. "Remote notifications" 체크
```

#### 2. Provisioning Profile 확인
```
Xcode → Runner → Signing & Capabilities

- Team: 올바른 Apple Developer Team 선택
- Provisioning Profile: Automatic 또는 수동 선택
- Signing Certificate: 유효한 인증서 확인

⚠️ 중요: Provisioning Profile에 Push Notifications 권한이 포함되어야 함
```

#### 3. Firebase Console APNs 키 업로드 확인
```
1. Firebase Console 접속
   https://console.firebase.google.com/

2. Project Settings (톱니바퀴) → Cloud Messaging

3. Apple app configuration 섹션 확인:
   - APNs 인증 키 (.p8) 업로드되어 있는지 확인
   - Key ID와 Team ID가 올바른지 확인

⚠️ 없다면: Apple Developer Console에서 APNs 인증 키 생성 후 업로드
```

#### 4. 네트워크 연결 확인
```
- 기기가 인터넷에 연결되어 있는지 확인
- 방화벽이나 VPN이 APNs 연결을 차단하지 않는지 확인
- Apple APNs 서버 연결 가능한지 확인:
  https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html
```

---

## ✅ 4단계: 성공적인 APNs 토큰 획득 시 로그

**정상 작동 시 예상 로그:**
```
🍎 APNs 원격 알림 등록 시작...
✅ APNs 등록 요청 전송 완료
   → didRegisterForRemoteNotificationsWithDeviceToken() 또는
   → didFailToRegisterForRemoteNotificationsWithError() 호출 대기 중...

============================================================
🍎 APNs 토큰 수신 성공
============================================================
📱 토큰: a1b2c3d4e5f6789...
📊 토큰 길이: 64 문자

✅ Firebase에 APNs 토큰 전달 중...
✅ APNs 토큰 전달 완료
   → Firebase가 이제 FCM 토큰을 생성합니다
============================================================

============================================================
✅ iOS 알림 권한 허용됨
============================================================

============================================================
🔔 FCM 토큰 수신 (iOS)
============================================================
📱 전체 토큰:
cYZ1234567890abcdefg...
📊 토큰 길이: 163 문자
✅ FCM 토큰 수신 완료
   → Flutter 앱에서 Firestore에 저장합니다
============================================================
```

---

## 🔧 5단계: 추가 디버깅 방법

### A. Xcode Console 필터링

Xcode Console 하단의 검색창에서:
```
🍎    # APNs 관련 로그만 보기
🔔    # FCM 관련 로그만 보기
✅    # 성공 로그만 보기
❌    # 오류 로그만 보기
Firebase  # Firebase 관련 모든 로그
```

---

### B. 로그 레벨 변경

더 상세한 Firebase 로그를 보려면:

**AppDelegate.swift에 추가:**
```swift
override func application(...) -> Bool {
  // Firebase 디버그 로깅 활성화
  FirebaseConfiguration.shared.setLoggerLevel(.debug)
  
  FirebaseApp.configure()
  ...
}
```

---

### C. Device Console 앱 사용 (Mac)

실제 기기의 모든 시스템 로그를 보려면:
```
1. Mac에서 "Console" 앱 실행 (Spotlight에서 검색)
2. 좌측에서 연결된 iPhone/iPad 선택
3. 검색창에 "MAKECALL" 또는 "Firebase" 입력
4. 실시간 로그 확인
```

---

## 📋 체크리스트

디버깅 전 이것들을 확인하세요:

### 기본 요구사항
- [ ] 실제 iOS 기기 사용 (시뮬레이터 아님)
- [ ] 기기가 인터넷 연결됨
- [ ] Xcode에서 Runner.xcworkspace 열기 (Runner.xcodeproj 아님)
- [ ] Clean Build Folder 실행 (Cmd+Shift+K)

### Firebase 설정
- [ ] GoogleService-Info.plist 파일 존재
- [ ] GoogleService-Info.plist가 Xcode 프로젝트에 추가됨
- [ ] Bundle Identifier 일치
- [ ] Firebase Console에 APNs 인증 키 업로드됨

### Xcode 설정
- [ ] Push Notifications capability 추가
- [ ] Background Modes capability 추가
- [ ] Remote notifications 체크
- [ ] Team 선택됨
- [ ] Provisioning Profile 유효함

### 코드 확인
- [ ] AppDelegate.swift 파일이 최신 버전
- [ ] Info.plist에 FirebaseAppDelegateProxyEnabled = false
- [ ] Info.plist에 UIBackgroundModes 배열에 remote-notification 포함

---

## 🆘 여전히 로그가 안 나온다면?

1. **Xcode 전체 재시작**
   ```bash
   killall Xcode
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

2. **iOS 프로젝트 완전 재빌드**
   ```bash
   cd ~/makecall/flutter_app
   ./ios_fix.sh
   ```

3. **Flutter 캐시 클리어**
   ```bash
   flutter clean
   flutter pub get
   ```

4. **기기 재시작**
   - iPhone/iPad 재부팅
   - Xcode 재시작
   - 다시 빌드

---

## 📞 다음 단계

로그가 정상적으로 출력되기 시작하면:

1. **APNs 토큰 수신 확인** → ✅ 
2. **FCM 토큰 수신 확인** → ✅
3. **Firestore에 토큰 저장 확인** → Firebase Console에서 fcm_tokens 컬렉션 확인
4. **테스트 알림 전송** → Firebase Console → Cloud Messaging

모든 단계가 성공하면 iOS 푸시 알림 시스템이 정상 작동합니다! 🎉
