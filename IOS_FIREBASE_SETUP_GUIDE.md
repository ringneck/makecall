# 🔥 iOS Firebase 설정 가이드

## 📋 문제 상황

**오류 메시지:**
```
Exception NSException *
`FirebaseApp.configure()` could not find a valid GoogleService-Info.plist in your project. 
Please download one from https://console.firebase.google.com/.
```

**원인:**
- Android 앱만 Firebase에 등록됨 (`google-services.json` 존재)
- iOS 앱이 Firebase에 미등록 (`GoogleService-Info.plist` 없음)
- Firebase는 플랫폼별로 별도 설정 파일 필요

---

## 🎯 해결 방법

iOS 앱을 Firebase Console에 등록하고 `GoogleService-Info.plist` 파일을 다운로드해야 합니다.

---

## ✅ 단계별 설정 가이드

### **Step 1: Firebase Console 접속**

1. Firebase Console 열기:
   ```
   https://console.firebase.google.com/
   ```

2. 프로젝트 선택:
   ```
   프로젝트 이름: makecallio
   Project ID: makecallio
   Project Number: 793164633643
   ```

---

### **Step 2: iOS 앱 추가**

1. **프로젝트 개요 페이지에서**:
   - 좌측 상단 "Project Overview" 옆 톱니바퀴 → **"프로젝트 설정"** 클릭

2. **"일반" 탭에서**:
   - 아래로 스크롤 → **"내 앱"** 섹션
   - iOS 앱이 없다면 **"+ iOS 앱 추가"** 버튼 클릭

3. **iOS 앱 등록 양식 입력**:

   #### A. iOS 번들 ID (필수)
   ```
   Bundle ID를 확인하는 방법:
   
   옵션 1: Xcode에서 확인
   - Xcode 열기: open ~/makecall/flutter_app/ios/Runner.xcworkspace
   - 좌측에서 "Runner" 프로젝트 클릭
   - TARGETS → Runner 선택
   - "General" 탭 → "Bundle Identifier" 확인
   
   옵션 2: project.pbxproj에서 확인
   - grep -r "PRODUCT_BUNDLE_IDENTIFIER" ~/makecall/flutter_app/ios/Runner.xcodeproj/project.pbxproj
   ```

   **예시 Bundle ID**:
   - `com.makecall.app` (권장)
   - `com.example.makecall`
   - 또는 Xcode에서 확인한 실제 Bundle ID 사용

   #### B. 앱 닉네임 (선택사항)
   ```
   MakeCall iOS
   ```

   #### C. App Store ID (선택사항)
   ```
   아직 App Store에 출시하지 않았다면 비워두세요
   나중에 추가 가능
   ```

4. **"앱 등록" 버튼 클릭**

---

### **Step 3: GoogleService-Info.plist 다운로드**

1. **Firebase Console에서 자동으로 다운로드 화면 표시**:
   - **"GoogleService-Info.plist 다운로드"** 버튼 클릭
   - 파일이 Mac의 Downloads 폴더에 저장됨

2. **만약 다운로드 화면을 놓쳤다면**:
   - Firebase Console → 프로젝트 설정 → "일반" 탭
   - "내 앱" → iOS 앱 찾기
   - **"GoogleService-Info.plist"** 링크 클릭 → 다운로드

3. **파일 위치 확인**:
   ```bash
   ls -la ~/Downloads/GoogleService-Info.plist
   ```

---

### **Step 4: Xcode 프로젝트에 파일 추가**

**⚠️ 중요: 파일을 단순히 복사하지 말고, Xcode를 통해 추가해야 합니다!**

#### 방법 1: Xcode에서 직접 추가 (권장)

1. **Xcode 열기**:
   ```bash
   open ~/makecall/flutter_app/ios/Runner.xcworkspace
   ```

2. **GoogleService-Info.plist 파일 추가**:
   - 좌측 Project Navigator에서 **"Runner"** 폴더 선택
   - 우클릭 → **"Add Files to "Runner"..."**
   - Downloads 폴더에서 `GoogleService-Info.plist` 파일 선택
   
3. **중요: 다음 옵션 반드시 체크**:
   ```
   ✅ Copy items if needed (파일을 프로젝트로 복사)
   ✅ Create groups (그룹 생성)
   ✅ Add to targets: Runner (Runner 타겟에 추가)
   ```

4. **"Add" 버튼 클릭**

5. **파일 위치 확인**:
   ```
   좌측 Project Navigator에서:
   Runner
   ├── AppDelegate.swift
   ├── Runner-Bridging-Header.h
   ├── Info.plist
   └── GoogleService-Info.plist  ← 이 위치에 있어야 함
   ```

#### 방법 2: 명령어로 복사 후 Xcode 재시작

```bash
# 파일 복사
cp ~/Downloads/GoogleService-Info.plist ~/makecall/flutter_app/ios/Runner/

# 파일 확인
ls -la ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# Xcode 재시작
killall Xcode
open ~/makecall/flutter_app/ios/Runner.xcworkspace
```

**⚠️ 주의**: 이 방법을 사용하면 Xcode에서 파일을 수동으로 프로젝트에 추가해야 합니다:
- 좌측에서 Runner 폴더 우클릭
- "Add Files to Runner..."
- 이미 있는 `GoogleService-Info.plist` 선택
- **"Copy items if needed" 체크 해제** (이미 복사했으므로)
- **"Add to targets: Runner" 체크**

---

### **Step 5: 파일 추가 확인**

#### A. Xcode에서 확인
```
1. 좌측 Project Navigator에서 "Runner" 폴더 확장
2. "GoogleService-Info.plist" 파일이 보여야 함
3. 파일 클릭 시 우측에 내용 표시되어야 함
```

#### B. Build Phases 확인
```
1. Xcode → Runner 프로젝트 → TARGETS → Runner
2. "Build Phases" 탭
3. "Copy Bundle Resources" 섹션 확장
4. "GoogleService-Info.plist"가 리스트에 있는지 확인
```

**만약 없다면**:
- "Copy Bundle Resources" 하단의 "+" 버튼 클릭
- "GoogleService-Info.plist" 찾아서 추가

#### C. 파일 시스템에서 확인
```bash
# 파일 존재 확인
ls -la ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# 파일 내용 확인 (Project ID 등)
grep -A 1 "PROJECT_ID" ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist
```

**예상 출력**:
```xml
<key>PROJECT_ID</key>
<string>makecallio</string>
```

---

### **Step 6: Bundle ID 일치 확인**

**매우 중요**: Xcode의 Bundle Identifier와 GoogleService-Info.plist의 BUNDLE_ID가 일치해야 합니다!

#### A. GoogleService-Info.plist의 Bundle ID 확인
```bash
grep -A 1 "BUNDLE_ID" ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist
```

**예상 출력**:
```xml
<key>BUNDLE_ID</key>
<string>com.makecall.app</string>
```

#### B. Xcode의 Bundle Identifier 확인
```
Xcode → Runner → TARGETS → Runner → General 탭
→ "Bundle Identifier" 필드 확인
```

#### C. 불일치 시 해결 방법

**옵션 1**: Xcode에서 Bundle ID 변경 (권장)
```
Xcode → Runner → TARGETS → Runner → General 탭
→ Bundle Identifier를 GoogleService-Info.plist의 BUNDLE_ID와 동일하게 변경
```

**옵션 2**: Firebase에서 iOS 앱 다시 등록
```
1. Firebase Console → 프로젝트 설정
2. "내 앱" → iOS 앱 찾기
3. 앱 삭제 (톱니바퀴 → 삭제)
4. 올바른 Bundle ID로 iOS 앱 다시 추가
5. GoogleService-Info.plist 다시 다운로드
```

---

### **Step 7: 빌드 및 실행**

1. **Xcode Clean Build**:
   ```
   Product → Clean Build Folder (Cmd+Shift+K)
   ```

2. **빌드**:
   ```
   Product → Build (Cmd+B)
   ```

3. **실행**:
   ```
   Product → Run (Cmd+R)
   ```

4. **Console 로그 확인**:
   ```
   예상 로그:
   ================================================================================
   🚀 AppDelegate.application() 실행 시작
   ================================================================================
   
   🔥 Firebase 초기화 중...
   ✅ Firebase 초기화 완료      ← 이 로그가 나와야 성공!
   ```

---

## 🔍 GoogleService-Info.plist 파일 구조

정상적인 파일은 다음과 같은 정보를 포함합니다:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_KEY</key>
    <string>AIzaSy...</string>
    
    <key>GCM_SENDER_ID</key>
    <string>793164633643</string>
    
    <key>PROJECT_ID</key>
    <string>makecallio</string>
    
    <key>STORAGE_BUCKET</key>
    <string>makecallio.firebasestorage.app</string>
    
    <key>GOOGLE_APP_ID</key>
    <string>1:793164633643:ios:xxxxx</string>
    
    <key>BUNDLE_ID</key>
    <string>com.makecall.app</string>
    
    <key>IS_ANALYTICS_ENABLED</key>
    <true/>
    
    <key>IS_APPINVITE_ENABLED</key>
    <true/>
    
    <key>IS_GCM_ENABLED</key>
    <true/>
    
    <key>IS_SIGNIN_ENABLED</key>
    <true/>
</dict>
</plist>
```

---

## 🆘 문제 해결

### **문제 1: Firebase Console에서 iOS 앱을 찾을 수 없음**

**원인**: iOS 앱이 아직 추가되지 않음

**해결**:
```
Firebase Console → 프로젝트 설정 → 일반 탭 → 내 앱 섹션
→ 현재 Android 앱만 있을 것임
→ "iOS 앱 추가" 버튼 클릭
```

---

### **문제 2: GoogleService-Info.plist 다운로드 후에도 오류 발생**

**원인**: 파일이 Xcode 프로젝트에 제대로 추가되지 않음

**확인 사항**:
```
1. Xcode Project Navigator에서 파일이 보이는가?
2. 파일이 회색으로 표시되지 않는가? (빨간색이면 파일 누락)
3. Build Phases → Copy Bundle Resources에 포함되어 있는가?
```

**해결**:
```bash
# 파일 존재 확인
ls -la ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# 없다면 다시 복사
cp ~/Downloads/GoogleService-Info.plist ~/makecall/flutter_app/ios/Runner/

# Xcode에서 프로젝트에 추가 (위의 Step 4 참조)
```

---

### **문제 3: Bundle ID 불일치 오류**

**증상**:
```
The BUNDLE_ID in the GoogleService-Info.plist does not match the Bundle Identifier
```

**확인**:
```bash
# GoogleService-Info.plist의 Bundle ID
grep -A 1 "BUNDLE_ID" ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# Xcode의 Bundle Identifier
grep -A 1 "PRODUCT_BUNDLE_IDENTIFIER" ~/makecall/flutter_app/ios/Runner.xcodeproj/project.pbxproj | head -3
```

**해결**:
- Xcode에서 Bundle Identifier를 GoogleService-Info.plist의 BUNDLE_ID와 동일하게 변경
- 또는 Firebase에서 올바른 Bundle ID로 iOS 앱 다시 등록

---

### **문제 4: 파일은 있지만 Firebase 초기화 실패**

**원인**: 파일 형식 오류 또는 손상

**확인**:
```bash
# XML 형식 확인
cat ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# PROJECT_ID 확인
grep "makecallio" ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist
```

**해결**:
- Firebase Console에서 파일 다시 다운로드
- 텍스트 편집기로 열어서 내용 확인
- XML 형식이 올바른지 검증

---

## 📊 Android vs iOS Firebase 설정 비교

| 구분 | Android | iOS |
|------|---------|-----|
| 설정 파일 | `google-services.json` | `GoogleService-Info.plist` |
| 파일 위치 | `android/app/` | `ios/Runner/` |
| 앱 식별자 | Package Name | Bundle Identifier |
| 파일 형식 | JSON | XML (plist) |
| Xcode 추가 | 불필요 | **필수** (Copy Bundle Resources) |

---

## ✅ 완료 확인 체크리스트

### 1. Firebase Console 확인
- [ ] Firebase Console → 프로젝트 설정 → "일반" 탭
- [ ] "내 앱" 섹션에 iOS 앱이 표시됨
- [ ] iOS 앱의 Bundle ID가 올바름

### 2. 파일 시스템 확인
- [ ] `ls -la ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist` 성공
- [ ] 파일 크기가 0보다 큼 (보통 1-2KB)
- [ ] `grep "makecallio" GoogleService-Info.plist` 성공

### 3. Xcode 프로젝트 확인
- [ ] Project Navigator에서 파일이 보임
- [ ] 파일이 회색/빨간색이 아닌 검은색 텍스트
- [ ] Build Phases → Copy Bundle Resources에 포함됨

### 4. Bundle ID 확인
- [ ] Xcode의 Bundle Identifier와 GoogleService-Info.plist의 BUNDLE_ID 일치
- [ ] Firebase Console의 iOS 앱 Bundle ID와 일치

### 5. 빌드 및 실행 확인
- [ ] Xcode 빌드 성공 (Cmd+B)
- [ ] Firebase 초기화 성공 로그 확인
- [ ] 앱 정상 실행

---

## 🎯 다음 단계

Firebase 설정이 완료되면:

1. **APNs 인증 키 업로드** (iOS 푸시 알림 필수)
   - Apple Developer Console에서 APNs 인증 키 생성
   - Firebase Console → 프로젝트 설정 → Cloud Messaging → APNs 업로드

2. **Xcode Capabilities 설정**
   - Push Notifications 추가
   - Background Modes 추가 (remote-notification)

3. **iOS FCM 테스트**
   - 실제 iOS 기기에서 앱 실행
   - APNs 토큰 획득 확인
   - FCM 토큰 생성 확인

---

## 📝 요약

**필수 작업**:
1. ✅ Firebase Console에서 iOS 앱 추가
2. ✅ GoogleService-Info.plist 다운로드
3. ✅ Xcode 프로젝트에 파일 추가 (Copy Bundle Resources)
4. ✅ Bundle ID 일치 확인
5. ✅ 빌드 및 Firebase 초기화 확인

**현재 상황**:
- Android 앱: ✅ 이미 등록됨 (`google-services.json`)
- iOS 앱: ❌ 미등록 → **Firebase Console에서 등록 필요**

iOS 앱을 Firebase에 등록하고 `GoogleService-Info.plist`를 Xcode 프로젝트에 추가하면 문제가 해결됩니다! 🚀
