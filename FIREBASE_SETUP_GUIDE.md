# Firebase iOS 설정 가이드

## 🚨 현재 문제
- `GoogleService-Info.plist` 파일이 없어서 FCM 연결 실패
- 네트워크 오류: `nw_endpoint_flow_failed_with_error`

## ✅ 해결 방법

### 1단계: Firebase Console에서 파일 다운로드

1. **Firebase Console 접속**
   ```
   https://console.firebase.google.com/
   ```

2. **프로젝트 선택**
   - 현재 사용 중인 Firebase 프로젝트 클릭

3. **프로젝트 설정 열기**
   - 왼쪽 상단 톱니바퀴 아이콘 (⚙️) 클릭
   - "프로젝트 설정" 선택

4. **iOS 앱 확인**
   - "일반" 탭 → "내 앱" 섹션
   - iOS 앱이 있는지 확인

### 2단계: iOS 앱 추가 (없는 경우)

1. **iOS 앱 추가 버튼 클릭**
   - "앱 추가" → iOS 아이콘 선택

2. **번들 ID 입력**
   ```
   Xcode에서 확인:
   1. ios/Runner.xcworkspace 열기
   2. Runner 프로젝트 선택
   3. "Signing & Capabilities" 탭
   4. Bundle Identifier 확인
   
   예시: com.makecall.app
   ```

3. **앱 닉네임 입력 (선택)**
   ```
   예시: MAKECALL iOS
   ```

4. **App Store ID (선택)**
   - 나중에 입력 가능 (건너뛰기)

5. **"앱 등록" 클릭**

### 3단계: GoogleService-Info.plist 다운로드

1. **구성 파일 다운로드**
   - "GoogleService-Info.plist 다운로드" 버튼 클릭
   - 파일을 안전한 위치에 저장

2. **파일 내용 확인**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
   <plist version="1.0">
   <dict>
       <key>CLIENT_ID</key>
       <string>...</string>
       <key>REVERSED_CLIENT_ID</key>
       <string>...</string>
       <key>API_KEY</key>
       <string>...</string>
       <key>GCM_SENDER_ID</key>
       <string>...</string>
       <key>PROJECT_ID</key>
       <string>...</string>
       <key>STORAGE_BUCKET</key>
       <string>...</string>
       ...
   </dict>
   </plist>
   ```

### 4단계: Xcode 프로젝트에 추가

1. **Xcode에서 프로젝트 열기**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **파일 추가**
   - 다운로드한 `GoogleService-Info.plist`를 Finder에서 찾기
   - Xcode의 `Runner` 폴더로 드래그 앤 드롭
   
3. **중요 설정 확인**
   - ✅ "Copy items if needed" 체크
   - ✅ "Runner" 타겟 선택
   - ✅ "Add to targets: Runner" 체크
   
4. **파일 위치 확인**
   ```
   ios/Runner/GoogleService-Info.plist
   ```

5. **Project Navigator에서 확인**
   - Runner 폴더 아래에 파일이 보여야 함
   - 파일을 클릭했을 때 "Target Membership" 탭에서 Runner가 체크되어 있어야 함

### 5단계: 앱 재빌드 및 테스트

1. **Clean Build Folder**
   ```
   Xcode 메뉴: Product → Clean Build Folder
   또는 단축키: Cmd + Shift + K
   ```

2. **앱 실행**
   ```
   실제 iOS 기기 선택
   실행: Cmd + R
   ```

3. **로그인 시도 후 콘솔 확인**
   ```
   예상 로그:
   ✅ [FCM] APNs 토큰 존재: 1234567890abcdef...
   ✅ [FCM] 토큰 생성 완료!
   ✅ [FCM-SAVE] Firestore 저장 완료!
   ```

## 🔍 추가 확인사항

### APNs 인증 키 설정 (FCM 푸시 알림용)

1. **Firebase Console**
   - 프로젝트 설정 → Cloud Messaging 탭
   - "Apple 앱 구성" 섹션

2. **APNs 인증 키 업로드**
   - Apple Developer에서 APNs 키 생성:
     https://developer.apple.com/account/resources/authkeys/list
   - .p8 파일 다운로드
   - Firebase Console에 업로드
   - Key ID와 Team ID 입력

### Push Notifications Capability 추가

1. **Xcode에서**
   - Runner 프로젝트 선택
   - "Signing & Capabilities" 탭
   - "+ Capability" 버튼
   - "Push Notifications" 추가
   - "Background Modes" 추가
     * "Remote notifications" 체크

## 📊 Firebase 설정 완료 후 확인

### Firestore에서 토큰 확인
```
Firebase Console
→ Firestore Database
→ fcm_tokens 컬렉션
→ 문서 ID: {userId}_{deviceId}

예시:
fcm_tokens/abc123_ios_iPhone15
├── userId: "abc123..."
├── fcmToken: "dGhpc2lzYWZha2V0b2..."
├── deviceId: "ios_iPhone15"
├── deviceName: "iPhone 15 Pro (iOS 17.0)"
├── platform: "ios"
├── createdAt: Timestamp
├── lastActiveAt: Timestamp
└── isActive: true
```

## ⚠️ 주의사항

1. **GoogleService-Info.plist는 민감한 정보 포함**
   - Git에 커밋하지 말 것 (.gitignore 확인)
   - 공개 저장소에 업로드 금지

2. **번들 ID 일치 필수**
   - Firebase Console의 번들 ID
   - Xcode의 Bundle Identifier
   - 두 값이 정확히 일치해야 함

3. **시뮬레이터 제한**
   - iOS 시뮬레이터는 APNs/FCM 푸시 알림 미지원
   - 반드시 실제 iOS 기기에서 테스트

## 🆘 문제 해결

### 문제: "File not found: GoogleService-Info.plist"
**해결:** Xcode에서 파일 추가 시 "Copy items if needed" 체크 확인

### 문제: "FCM token still not generated"
**해결:** 
1. Clean Build Folder (Cmd + Shift + K)
2. 앱 삭제 후 재설치
3. 네트워크 연결 확인

### 문제: "APNs token is nil"
**해결:**
1. Firebase Console에서 APNs 인증 키 업로드
2. Xcode에서 Push Notifications Capability 추가
3. 실제 기기에서 테스트 (시뮬레이터 X)

## 📞 추가 지원

문제가 계속되면 다음 정보를 공유해주세요:
1. Xcode 콘솔의 전체 FCM 로그
2. Firebase Console 스크린샷 (iOS 앱 설정 부분)
3. Xcode Bundle Identifier
4. 테스트 기기 정보 (iOS 버전)
