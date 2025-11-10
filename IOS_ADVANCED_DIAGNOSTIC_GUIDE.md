# iOS Firebase 고급 진단 가이드

## 🎯 목적

이 문서는 iOS Firebase 중복 초기화 및 APNs 토큰 이중 출력 문제를 해결하기 위한 **프로덕션급 진단 시스템**을 설명합니다.

---

## 🔍 구현된 진단 시스템

### 3계층 로깅 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│              1. iOS Native Layer (Swift)                    │
│  [NATIVE-001~FINISH] AppDelegate 생명주기 추적              │
│  [NATIVE-APNS-001~006] APNs 토큰 등록 추적                 │
│  - 호출 카운터 (중복 감지)                                  │
│  - 호출 스택 추적 (caller 식별)                             │
│  - Thread/DispatchQueue 추적                                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              2. Flutter Engine Layer (Dart)                 │
│  [TRACE-001~012] main() 초기화 플로우                       │
│  [BACKGROUND-001~005] 백그라운드 핸들러                     │
│  [WIDGET-001~008] MyApp 위젯 생명주기                       │
│  - Firebase.apps 상태 체크                                  │
│  - ISO8601 타임스탬프                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              3. FCM Service Layer (Dart)                    │
│  [FCM-001~007] FCM 초기화 상세 추적                         │
│  [FCM-iOS-001~005] iOS APNs 토큰 획득                      │
│  - Firebase Messaging 인스턴스 상태                         │
│  - 권한 요청/응답 추적                                      │
│  - APNs/FCM 토큰 획득 타임라인                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 로그 ID 체계

### Native Layer (Swift)

| Trace ID | 위치 | 설명 |
|----------|------|------|
| `NATIVE-001` | didFinishLaunching | AppDelegate 시작 |
| `NATIVE-002` | didFinishLaunching | 호출 스택 추적 |
| `NATIVE-FINISH` | didFinishLaunching | 메서드 완료 |
| `NATIVE-SUPER` | didFinishLaunching | super.application() 호출 전 |
| `NATIVE-COMPLETE` | didFinishLaunching | super.application() 반환 후 |
| `NATIVE-APNS-001` | didRegisterForRemoteNotifications | APNs 토큰 수신 시작 |
| `NATIVE-APNS-002` | didRegisterForRemoteNotifications | 호출 스택 추적 (누가 호출했는지) |
| `NATIVE-APNS-003` | didRegisterForRemoteNotifications | 토큰 정보 상세 |
| `NATIVE-APNS-004` | didRegisterForRemoteNotifications | 현재 상태 체크 |
| `NATIVE-APNS-005` | didRegisterForRemoteNotifications | Flutter 플러그인 자동 처리 안내 |
| `NATIVE-APNS-006` | didRegisterForRemoteNotifications | 메서드 종료 |
| `NATIVE-APNS-WARNING` | didRegisterForRemoteNotifications | 중복 호출 경고 (호출 횟수 > 1) |

### Flutter Layer (Dart)

| Trace ID | 위치 | 설명 |
|----------|------|------|
| `TRACE-001` | main() | 시작 |
| `TRACE-002` | main() | WidgetsFlutterBinding 초기화 |
| `TRACE-003` | main() | Firebase 초기화 전 상태 |
| `TRACE-004` | main() | Firebase.initializeApp() 호출 |
| `TRACE-005` | main() | Firebase 초기화 완료 |
| `TRACE-ERROR-005` | main() | Firebase 초기화 실패 |
| `TRACE-006` | main() | FCM 백그라운드 핸들러 등록 시작 |
| `TRACE-007` | main() | FCM 백그라운드 핸들러 등록 완료 |
| `TRACE-008` | main() | Hive 초기화 시작 |
| `TRACE-009` | main() | Hive 초기화 완료 |
| `TRACE-010` | main() | UserSessionManager 초기화 시작 |
| `TRACE-011` | main() | UserSessionManager 초기화 완료 |
| `TRACE-012` | main() | runApp() 호출 |
| `BACKGROUND-001` | 백그라운드 핸들러 | 실행 시작 |
| `BACKGROUND-002` | 백그라운드 핸들러 | Firebase 상태 체크 |
| `BACKGROUND-003` | 백그라운드 핸들러 | Firebase 초기화 (필요 시) |
| `BACKGROUND-004` | 백그라운드 핸들러 | Firebase 초기화 완료/실패 |
| `BACKGROUND-005` | 백그라운드 핸들러 | 메시지 상세 정보 |
| `WIDGET-001` | MyApp.initState() | 시작 |
| `WIDGET-002` | MyApp.initState() | Firebase 상태 체크 |
| `WIDGET-003` | MyApp.initState() | NavigatorKey 등록 시작 |
| `WIDGET-004` | MyApp.initState() | NavigatorKey 등록 완료 |
| `WIDGET-005` | MyApp.initState() | FCM 강제 로그아웃 콜백 설정 시작 |
| `WIDGET-006` | MyApp.initState() | FCM 강제 로그아웃 콜백 설정 완료 |
| `WIDGET-007` | MyApp.initState() | WebSocket 연결 관리자 시작 예약 |
| `WIDGET-008` | MyApp.initState() | initState() 완료 |
| `WIDGET-POST-FRAME` | addPostFrameCallback | WebSocket 연결 시작 |
| `WIDGET-CALLBACK` | 강제 로그아웃 콜백 | 실행 |

### FCM Service Layer (Dart)

| Trace ID | 위치 | 설명 |
|----------|------|------|
| `FCM-001` | initialize() | FCM 초기화 시작 |
| `FCM-002` | initialize() | Firebase Messaging 인스턴스 상태 |
| `FCM-003` | initialize() | requestPermission() 호출 시작 |
| `FCM-004` | initialize() | requestPermission() 완료 |
| `FCM-005` | initialize() | getToken() 호출 시작 (모바일) |
| `FCM-006` | initialize() | getToken() 완료 |
| `FCM-007` | initialize() | FCM 토큰 생성 완료 |
| `FCM-iOS-001` | initialize() (iOS) | iOS FCM 초기화 시작 |
| `FCM-iOS-002` | initialize() (iOS) | requestPermission() 호출 전 |
| `FCM-iOS-003` | initialize() (iOS) | getAPNSToken() 호출 시작 |
| `FCM-iOS-004` | initialize() (iOS) | getAPNSToken() 완료 |
| `FCM-iOS-005` | initialize() (iOS) | APNs 토큰 획득 성공 |
| `FCM-iOS-ERROR-005` | initialize() (iOS) | APNs 토큰 획득 실패 |

---

## 🧪 진단 절차

### 1단계: 로그 수집

Mac Xcode에서 빌드 후 Console 로그를 **전체 복사**하세요.

```bash
# Xcode에서 실행 후
# View → Debug Area → Activate Console (⇧⌘C)
# 전체 로그를 텍스트 파일로 저장
```

---

### 2단계: 핵심 지표 분석

#### A. APNs 토큰 호출 횟수 확인

```bash
# 로그에서 검색:
grep "NATIVE-APNS-001" xcode_log.txt | wc -l
```

**예상 결과**:
- ✅ `1` - 정상 (한 번만 호출)
- 🚨 `2` 이상 - 문제! (중복 호출)

만약 `2` 이상이면, `NATIVE-APNS-WARNING` 로그를 찾아서 호출 스택을 분석하세요.

---

#### B. Firebase 초기화 횟수 확인

```bash
# Flutter 레이어 초기화
grep "TRACE-005" xcode_log.txt | wc -l

# 백그라운드 핸들러 초기화
grep "BACKGROUND-004" xcode_log.txt | wc -l
```

**예상 결과**:
- ✅ `TRACE-005`: 1회 (main()에서 한 번)
- ✅ `BACKGROUND-004`: 0회 (백그라운드 메시지 없으면 실행 안 됨)

---

#### C. 타임라인 재구성

로그를 Trace ID 순서로 정렬하여 실행 순서를 파악하세요:

```
NATIVE-001 (iOS 앱 시작)
  → TRACE-001 (Flutter main() 시작)
    → TRACE-003 (Firebase 초기화 전)
    → TRACE-005 (Firebase 초기화 완료)
    → WIDGET-001 (MyApp initState)
      → FCM-001 (FCM 초기화 시작)
        → FCM-iOS-003 (getAPNSToken 호출)
        → NATIVE-APNS-001 (APNs 토큰 수신) ← 여기가 중요!
```

---

### 3단계: 호출 스택 분석

`NATIVE-APNS-002`에서 출력된 호출 스택을 분석하세요:

```
🔍 [NATIVE-APNS-002] 호출 스택 추적:
   [0] AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
   [1] -[UIApplication _setRemoteNotificationRegistrationInfo:]
   [2] __63-[UIApplication registerForRemoteNotifications]_block_invoke
   [3] ...
```

**중요 포인트**:
- `[1]`에서 `UIApplication` 관련 메서드가 보이면 → iOS 시스템이 정상적으로 호출
- `[1]`에서 `Flutter` 또는 `Firebase` 관련 메서드가 보이면 → Flutter/Firebase가 재호출하고 있음

---

### 4단계: FirebaseAppDelegateProxyEnabled 영향 분석

Info.plist에서 `FirebaseAppDelegateProxyEnabled`를 `true`로 설정했으므로:

**예상 동작**:
1. Firebase SDK가 자동으로 `didRegisterForRemoteNotificationsWithDeviceToken` 메서드를 **swizzle** (교체)
2. Firebase가 APNs 토큰을 자동으로 가로채서 처리
3. 우리가 override한 메서드도 호출됨

**확인 방법**:
- 로그에서 `NATIVE-APNS-001`이 **한 번만** 출력되는지 확인
- Firebase가 자동으로 처리하면, Flutter 플러그인도 토큰을 받아야 함
- `FCM-iOS-005`에서 APNs 토큰 획득 성공 로그 확인

---

## 🔧 문제 패턴별 해결 방법

### 패턴 1: APNs 토큰 2회 출력

**증상**:
```
NATIVE-APNS-001 (호출 #1)
...
NATIVE-APNS-001 (호출 #2) ← 중복!
NATIVE-APNS-WARNING (중복 호출 감지)
```

**원인 후보**:
1. FlutterAppDelegate가 이벤트를 재전파
2. Firebase AppDelegate Proxy가 메서드를 두 번 호출
3. UIApplication이 토큰을 두 번 전달 (iOS 버그)

**해결책**:
```swift
// 옵션 A: override하지 않기 (Firebase가 자동 처리)
// didRegisterForRemoteNotificationsWithDeviceToken 메서드 전체 제거

// 옵션 B: 호출 카운터로 중복 차단
override func application(...) {
  apnsTokenCallCount += 1
  guard apnsTokenCallCount == 1 else {
    print("⚠️ 중복 호출 무시")
    return
  }
  // 로그만 출력
}
```

---

### 패턴 2: Firebase 중복 초기화

**증상**:
```
TRACE-005 (Firebase 초기화 완료)
...
BACKGROUND-003 (Firebase 미초기화 감지 - 초기화 시작)
BACKGROUND-004 (Firebase 초기화 완료)
[ERROR] [core/duplicate-app] already exists
```

**원인**:
- 백그라운드 핸들러에서 `Firebase.apps.isEmpty` 체크가 실패
- 백그라운드 핸들러가 별도의 isolate에서 실행되어 Firebase 상태를 공유하지 못함

**해결책**:
- 이미 구현됨 (`BACKGROUND-002`에서 체크)
- 로그에서 `Firebase.apps.isEmpty: false`인지 확인

---

### 패턴 3: FCM 토큰 생성 실패

**증상**:
```
FCM-iOS-003 (getAPNSToken 호출)
FCM-iOS-004 (getAPNSToken 완료)
FCM-iOS-ERROR-005 (APNs 토큰 획득 실패)
```

**원인**:
- APNs 토큰이 Native에서 수신되지 않음
- Flutter 플러그인이 토큰을 감지하지 못함

**해결책**:
1. Native 로그에서 `NATIVE-APNS-001` 확인
2. `FirebaseAppDelegateProxyEnabled: true` 설정 확인
3. Xcode Capabilities에서 Push Notifications 추가 확인

---

## 📝 로그 분석 체크리스트

### Native Layer
- [ ] `NATIVE-001` 호출 횟수 확인 (1회 예상)
- [ ] `NATIVE-APNS-001` 호출 횟수 확인 (1회 예상)
- [ ] `NATIVE-APNS-WARNING` 존재 여부 (없어야 정상)
- [ ] `NATIVE-APNS-002` 호출 스택 분석
- [ ] Thread/DispatchQueue 정보 확인

### Flutter Layer
- [ ] `TRACE-001~012` 순차 실행 확인
- [ ] `TRACE-005` 한 번만 실행 확인
- [ ] `Firebase.apps.length` 값 확인 (0 → 1)
- [ ] `BACKGROUND-002`에서 Firebase.apps.isEmpty 확인

### FCM Layer
- [ ] `FCM-001~007` 순차 실행 확인
- [ ] `FCM-iOS-005` APNs 토큰 획득 성공 확인
- [ ] `FCM-007` FCM 토큰 생성 완료 확인
- [ ] Firestore 저장 로그 확인

---

## 🎯 다음 단계

### 로그 수집 후 분석

1. Mac에서 Xcode로 빌드 및 실행
2. Console 전체 로그 복사
3. 위 체크리스트에 따라 분석
4. 문제 패턴 식별
5. 해당 패턴의 해결책 적용

### 추가 테스트

FirebaseAppDelegateProxyEnabled 영향 확인을 위해:

**테스트 A**: `true` (현재 설정)
- APNs 토큰 1회 출력 예상
- Firebase가 자동 처리

**테스트 B**: `false` (이전 설정)
- APNs 토큰 2회 출력 가능성
- 수동 처리 필요

---

## 📞 문제 보고 시 포함 정보

GitHub Issue 또는 피드백 시 다음 정보를 포함해 주세요:

1. **전체 Xcode Console 로그** (텍스트 파일)
2. **핵심 지표**:
   - `NATIVE-APNS-001` 호출 횟수
   - `TRACE-005` 호출 횟수
   - `FCM-007` 존재 여부
3. **호출 스택** (`NATIVE-APNS-002` 전체 출력)
4. **Info.plist 설정**:
   - `FirebaseAppDelegateProxyEnabled` 값
   - `FirebaseMessagingAutoInitEnabled` 값
5. **iOS 버전 및 기기 정보**

---

**마지막 업데이트**: 2025-01-23  
**버전**: Advanced Diagnostic v1.0  
**상태**: 프로덕션 준비 완료
