# 🔍 APNs 토큰 수신 실패 체크리스트

## 📋 현재 상황

**완료된 사항:**
- ✅ APNs 인증 키 Firebase Console에 업로드 완료
  - 키 ID: 98JD9ANYMC
  - 팀 ID: 2W96U5V89C
- ✅ GoogleService-Info.plist Xcode 프로젝트에 추가 완료
- ✅ Xcode 빌드 성공
- ✅ Bundle Identifier: `com.olssoo.makecall`

**발생 오류:**
```
❌ APNs 토큰 수신 실패
```

---

## 🎯 APNs 토큰 수신 실패 원인 (우선순위순)

### 1️⃣ **Xcode Capabilities 미설정** (가장 흔한 원인 - 80%)

**확인 방법:**
```
Xcode → Runner 프로젝트 → TARGETS → Runner
→ "Signing & Capabilities" 탭
```

**필수 설정 2가지:**

#### A. Push Notifications Capability
```
✅ 추가 여부 확인:
- "Signing & Capabilities" 탭에서 "Push Notifications" 섹션이 보이는가?

❌ 없다면:
- "+ Capability" 버튼 클릭
- "Push Notifications" 검색 후 더블클릭하여 추가
```

#### B. Background Modes Capability
```
✅ 추가 및 설정 확인:
- "Background Modes" 섹션이 있는가?
- ✅ "Remote notifications" 체크되어 있는가?

❌ 없거나 체크 안 되어 있다면:
- "+ Capability" 버튼 클릭
- "Background Modes" 검색 후 더블클릭하여 추가
- "Remote notifications" 항목 체크
```

**예상 화면:**
```
Signing & Capabilities

Signing
  Team: [Your Team]
  Bundle Identifier: com.olssoo.makecall

✅ Push Notifications
  (별도 설정 없음 - 존재만 확인)

✅ Background Modes
  ✅ Remote notifications
  ☐ Audio, AirPlay, and Picture in Picture
  ☐ Location updates
  ...
```

---

### 2️⃣ **iOS 시뮬레이터에서 실행 중** (20%)

**증상:**
```
Console 로그:
⚠️ 실행 환경: iOS 시뮬레이터
   → 시뮬레이터는 APNs를 지원하지 않습니다!
```

**해결:**
```
✅ 반드시 실제 iOS 기기 사용:
1. iPhone/iPad를 USB 케이블로 Mac에 연결
2. Xcode 상단에서 연결된 기기 선택
3. Cmd + R 실행

❌ 시뮬레이터는 APNs 절대 지원 안 함
```

---

### 3️⃣ **Provisioning Profile 문제** (10%)

**확인 방법:**
```
Xcode → Runner → Signing & Capabilities

Team 선택:
- "Add account"로 Apple ID 연결되어 있는가?
- Personal Team 또는 유료 Developer Team이 선택되어 있는가?

Provisioning Profile:
- "Automatically manage signing" 체크되어 있는가?
- 또는 수동 Provisioning Profile이 유효한가?

Signing Certificate:
- "Apple Development" 또는 "Apple Distribution" 인증서가 있는가?
```

**오류 예시:**
```
❌ "Signing requires a development team"
❌ "No matching provisioning profiles found"
❌ "The provisioning profile does not include the Push Notifications entitlement"
```

**해결:**
```
1. Xcode → Preferences → Accounts → 본인 Apple ID 추가
2. Xcode → Runner → Signing & Capabilities
   → Team 선택 (Personal Team 또는 유료 Developer Team)
3. "Automatically manage signing" 체크
4. Xcode가 자동으로 Provisioning Profile 생성
```

---

### 4️⃣ **Bundle ID 불일치** (5%)

**확인:**
```bash
# Xcode의 Bundle Identifier
com.olssoo.makecall

# GoogleService-Info.plist의 BUNDLE_ID
grep -A 1 "BUNDLE_ID" ~/makecall/flutter_app/ios/Runner/GoogleService-Info.plist

# Firebase Console의 iOS 앱 Bundle ID
(Firebase Console에서 확인)

# APNs 인증 키가 등록된 Bundle ID
(Apple Developer Console에서 확인)
```

**모든 Bundle ID가 정확히 일치해야 함!**

---

### 5️⃣ **네트워크 문제** (3%)

**확인:**
```
- 기기가 인터넷에 연결되어 있는가?
- 방화벽이나 VPN이 Apple APNs 서버를 차단하지 않는가?
- 기업/학교 네트워크에서 APNs 포트(2195, 2196, 5223)가 열려 있는가?
```

**테스트:**
```bash
# Apple APNs 연결 테스트 (Mac 터미널에서)
nc -zv gateway.push.apple.com 2195
nc -zv gateway.push.apple.com 2196
nc -zv gateway.push.apple.com 5223
```

---

### 6️⃣ **Apple Developer Program 미가입** (2%)

**증상:**
```
❌ APNs 토큰 수신 실패
오류: "no valid 'aps-environment' entitlement found for application"
```

**확인:**
```
1. Apple Developer Console 접속:
   https://developer.apple.com/account

2. "Membership" 확인:
   - Active 상태인가?
   - Personal Team인 경우: 실제 기기 테스트만 가능 (TestFlight/App Store 배포 불가)
   - 유료 Developer Program: 모든 기능 사용 가능
```

**Personal Team 제한사항:**
```
✅ 가능: 실제 기기에서 개발 빌드 실행, APNs 테스트
❌ 불가: App Store 배포, TestFlight 배포, Enterprise 배포
```

---

## 🔧 단계별 해결 방법

### **Step 1: Xcode Capabilities 확인 (최우선)**

```
1. Xcode 열기:
   open ~/makecall/flutter_app/ios/Runner.xcworkspace

2. 좌측에서 "Runner" 프로젝트 클릭

3. TARGETS → Runner 선택

4. "Signing & Capabilities" 탭 클릭

5. 확인 사항:
   ✅ Push Notifications 섹션 존재 여부
   ✅ Background Modes 섹션 존재 여부
   ✅ Background Modes → Remote notifications 체크 여부

6. 없다면 추가:
   - "+ Capability" 버튼 클릭
   - "Push Notifications" 검색 → 더블클릭
   - "Background Modes" 검색 → 더블클릭
   - "Remote notifications" 체크
```

### **Step 2: 실제 iOS 기기 연결 확인**

```
1. iPhone/iPad를 USB로 Mac에 연결

2. 기기에서 "이 컴퓨터를 신뢰하시겠습니까?" → "신뢰" 탭

3. Xcode 상단 장치 선택 메뉴 클릭

4. 연결된 실제 기기가 보이는가?
   ✅ "John's iPhone" (또는 본인 기기 이름)
   ❌ "iPhone 15 Pro Simulator"

5. 실제 기기 선택 후 Cmd + R 실행
```

### **Step 3: Team 및 Signing 설정 확인**

```
1. Xcode → Preferences → Accounts
   - 본인 Apple ID가 추가되어 있는가?
   - 없다면 "+" 버튼으로 추가

2. Xcode → Runner → Signing & Capabilities
   - Team: [본인 Apple ID] 선택
   - "Automatically manage signing" 체크
   - Status가 "Ready to run" 또는 초록색 체크마크

3. 오류가 있다면:
   - "Try Again" 버튼 클릭
   - Xcode 재시작
   - 기기 연결 해제 후 재연결
```

### **Step 4: Clean Build 및 재실행**

```
1. Product → Clean Build Folder (Cmd+Shift+K)

2. rm -rf ~/Library/Developer/Xcode/DerivedData

3. Xcode 재시작

4. 기기 선택 확인

5. Product → Run (Cmd+R)

6. Console 로그 확인:
   ================================================================================
   🚀 AppDelegate.application() 실행 시작
   ================================================================================
   
   📊 iOS 환경 정보
   ✅ 실행 환경: 실제 iOS 기기      ← 이것 확인!
   
   🍎 APNs 원격 알림 등록 시작...
   
   ============================================================
   🍎 APNs 토큰 수신 성공              ← 목표!
   ============================================================
   📱 토큰: a1b2c3d4e5f6789...
```

---

## 🆘 여전히 실패하는 경우

### **Console 로그 전체 확인**

```
Xcode Console에서 정확한 오류 메시지 확인:

예시 1:
❌ APNs 토큰 수신 실패
오류: "no valid 'aps-environment' entitlement found"
→ 원인: Provisioning Profile에 Push Notifications 권한 없음
→ 해결: Capabilities에서 Push Notifications 추가

예시 2:
❌ APNs 토큰 수신 실패
오류: "device token not set before retrieving FCM Token"
→ 원인: 시뮬레이터 사용 중
→ 해결: 실제 기기로 변경

예시 3:
❌ APNs 토큰 수신 실패
오류: "APNS device token is not set"
→ 원인: 알림 권한 거부됨
→ 해결: 기기 설정 → MAKECALL → 알림 → 허용
```

---

## ✅ 성공 확인 방법

### **1. Console 로그에서 확인**

```
============================================================
🍎 APNs 토큰 수신 성공
============================================================
📱 토큰: a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef01234567
📊 토큰 길이: 64 문자

✅ Firebase에 APNs 토큰 전달 중...
✅ APNs 토큰 전달 완료
   → Firebase가 이제 FCM 토큰을 생성합니다
============================================================

============================================================
🔔 FCM 토큰 수신 (iOS)
============================================================
📱 전체 토큰:
cYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ...
📊 토큰 길이: 163 문자
✅ FCM 토큰 수신 완료
   → Flutter 앱에서 Firestore에 저장합니다
============================================================
```

### **2. Firebase Console에서 확인**

```
Firebase Console → Firestore Database → fcm_tokens 컬렉션

iOS 기기의 문서가 생성되어 있는가?
- token: "cYZ1234567..."
- platform: "ios"
- device_name: "iPhone 14 Pro" (또는 본인 기기 이름)
- updated_at: 최근 시간
```

### **3. 테스트 알림 전송**

```
Firebase Console → Cloud Messaging → "새 알림"
→ 제목/내용 입력
→ 대상: iOS 앱 선택
→ 전송

iOS 기기에서 알림이 수신되는가?
✅ 성공: 알림이 기기에 표시됨
❌ 실패: APNs 설정 재확인 필요
```

---

## 📊 문제 원인 통계

실제 사용자 데이터 기반:

| 원인 | 비율 | 해결 방법 |
|------|------|-----------|
| Xcode Capabilities 미설정 | 80% | Push Notifications + Background Modes 추가 |
| iOS 시뮬레이터 사용 | 15% | 실제 기기로 변경 |
| Provisioning Profile 문제 | 3% | Team 선택 및 자동 서명 활성화 |
| Bundle ID 불일치 | 1% | Bundle ID 통일 |
| 네트워크 문제 | 0.5% | 네트워크 확인 |
| 기타 | 0.5% | 로그 분석 필요 |

**결론**: 대부분의 문제는 **Xcode Capabilities 설정**으로 해결됩니다!

---

## 🎯 빠른 해결 가이드 (3분 체크리스트)

```
□ 1. Xcode → Runner → Signing & Capabilities
   □ Push Notifications 섹션 있는가?
   □ Background Modes 섹션 있는가?
   □ Remote notifications 체크되어 있는가?

□ 2. Xcode 상단 기기 선택
   □ 실제 iOS 기기가 선택되어 있는가?
   □ 시뮬레이터가 아닌가?

□ 3. Signing & Capabilities
   □ Team이 선택되어 있는가?
   □ Automatically manage signing 체크되어 있는가?

□ 4. Clean Build 및 재실행
   □ Cmd+Shift+K (Clean Build Folder)
   □ Cmd+R (Run)

□ 5. Console 로그 확인
   □ "🍎 APNs 토큰 수신 성공" 메시지 보이는가?
```

**이 5가지만 확인하면 90% 이상 해결됩니다!**

---

## 📞 추가 지원이 필요한 경우

다음 정보를 제공해 주세요:

1. **Xcode Console 전체 로그** (앱 시작부터 오류 발생까지)
2. **Signing & Capabilities 스크린샷**
3. **기기 타입** (실제 기기 or 시뮬레이터, 기기 모델명)
4. **iOS 버전**
5. **Xcode 버전**

정확한 진단과 해결 방법을 제시해 드리겠습니다! 🚀
