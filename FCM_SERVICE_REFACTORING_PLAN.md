# 🔧 FCM Service 리팩토링 계획

## 📊 현재 상태 분석

**파일 크기**: 3,405 줄, 132KB
**메서드 수**: 44개
**주요 문제점**:
- 단일 파일에 너무 많은 책임
- 메서드들이 기능별로 분리되지 않음
- 테스트와 유지보수가 어려움

---

## 🎯 리팩토링 목표

1. **단일 책임 원칙(SRP)** 적용
2. **기능별 모듈화**
3. **코드 재사용성 향상**
4. **테스트 용이성 개선**
5. **가독성 향상**

---

## 📁 제안하는 파일 구조

```
lib/services/fcm/
├── fcm_service.dart                    # Main entry point (통합 관리)
├── fcm_token_manager.dart              # FCM 토큰 관리
├── fcm_device_approval_service.dart    # 기기 승인 관련
├── fcm_message_handler.dart            # 메시지 수신 처리
├── fcm_notification_service.dart       # 알림 표시 (Android/iOS/Web)
├── fcm_incoming_call_handler.dart      # 수신 전화 처리
└── fcm_platform_utils.dart             # 플랫폼별 유틸리티
```

---

## 📋 메서드 분류 및 재배치

### 1️⃣ **FCMService** (Main - 150줄)
- `initialize()` - 초기화
- `handleRemoteMessage()` - 메시지 라우팅
- `deactivateToken()` - 토큰 비활성화
- Static setters (setContext, setAuthService, etc.)

**책임**: FCM 서비스 통합 관리 및 라우팅

---

### 2️⃣ **FCMTokenManager** (신규 - 300줄)
현재 위치의 메서드들:
- `_saveFCMToken()` - Line 469
- `_getDeviceId()` - Line 2560
- `_getDeviceName()` - Line 2651
- `_getPlatformName()` - Line 2739
- `_getiOSFriendlyName()` - Line 2700
- Token refresh 로직

**책임**: FCM 토큰 생명주기 관리

```dart
class FCMTokenManager {
  Future<void> saveToken(String userId, String token);
  Future<String> getDeviceId();
  Future<String> getDeviceName();
  String getPlatformName();
  Future<void> refreshToken(String userId);
  Future<void> deactivateToken(String userId, String deviceId, String platform);
}
```

---

### 3️⃣ **FCMDeviceApprovalService** (신규 - 800줄)
현재 위치의 메서드들:
- `_sendDeviceApprovalRequestAndWait()` - Line 693
- `_sendDeviceApprovalRequest()` - Line 725
- `_waitForDeviceApproval()` - Line 855
- `_handleDeviceApprovalRequest()` - Line 1463
- `_handleDeviceApprovalResponse()` - Line 1692
- `_approveDeviceApproval()` - Line 1797
- `_rejectDeviceApproval()` - Line 1846
- `_showApprovalWaitingDialog()` - Line 2925
- `_dismissApprovalWaitingDialog()` - Line 3069
- `resendApprovalRequest()` - Line 2984
- `handlePendingApprovalRequest()` - Line 1448
- `_triggerDeviceApprovalVibration()` - Line 3089
- `_triggerDeviceApprovalSound()` - Line 3143

**책임**: 기기 승인 요청/응답 처리

```dart
class FCMDeviceApprovalService {
  Future<String?> sendApprovalRequestAndWait({...});
  Future<bool> waitForApproval(String approvalRequestId);
  Future<void> approveDevice(String approvalRequestId);
  Future<void> rejectDevice(String approvalRequestId);
  void showApprovalWaitingDialog();
  void dismissApprovalWaitingDialog();
}
```

---

### 4️⃣ **FCMMessageHandler** (신규 - 400줄)
현재 위치의 메서드들:
- `_handleForegroundMessage()` - Line 941
- `_handleMessageOpenedApp()` - Line 1074
- `_handleForceLogout()` - Line 1369
- `_handleIncomingCallCancelled()` - Line 1734
- Message routing logic

**책임**: FCM 메시지 수신 및 라우팅

```dart
class FCMMessageHandler {
  void handleForegroundMessage(RemoteMessage message);
  void handleBackgroundMessage(RemoteMessage message);
  void handleMessageOpenedApp(RemoteMessage message);
  void handleForceLogout(RemoteMessage message);
  void handleIncomingCallCancelled(RemoteMessage message);
}
```

---

### 5️⃣ **FCMNotificationService** (신규 - 500줄)
현재 위치의 메서드들:
- `_showAndroidNotification()` - Line 1892
- `_showWebNotification()` - Line 2023
- `_showIOSNotification()` - Line 2052
- `getUserNotificationSettings()` - Line 2425
- `updateNotificationSettings()` - Line 2457
- `updateSingleSetting()` - Line 2483
- `checkIOSAPNsStatus()` - Line 2751

**책임**: 플랫폼별 알림 표시

```dart
class FCMNotificationService {
  Future<void> showNotification(RemoteMessage message);
  Future<void> showAndroidNotification(RemoteMessage message);
  Future<void> showIOSNotification(RemoteMessage message);
  Future<void> showWebNotification(RemoteMessage message);
  Future<Map<String, dynamic>?> getUserSettings(String userId);
  Future<void> updateSettings(String userId, Map<String, bool> settings);
}
```

---

### 6️⃣ **FCMIncomingCallHandler** (신규 - 600줄)
현재 위치의 메서드들:
- `_handleIncomingCallFCM()` - Line 1136
- `_showIncomingCallScreen()` - Line 2225
- `_waitForContextAndShowIncomingCall()` - Line 1240
- `_ensureWebSocketConnection()` - Line 2140
- `_createCallHistory()` - Line 2795
- `_extractPhoneNumber()` - Line 2778

**책임**: 수신 전화 FCM 처리

```dart
class FCMIncomingCallHandler {
  Future<void> handleIncomingCall(RemoteMessage message);
  Future<void> showIncomingCallScreen(RemoteMessage message);
  Future<void> createCallHistory({...});
  Future<void> ensureWebSocketConnection();
}
```

---

### 7️⃣ **FCMPlatformUtils** (신규 - 200줄)
현재 위치의 메서드들:
- Platform detection logic
- Device info utilities
- Timer and formatting utilities
- `_formatTime()` - Line 3283

**책임**: 플랫폼 관련 유틸리티

```dart
class FCMPlatformUtils {
  static bool get isIOS;
  static bool get isAndroid;
  static bool get isWeb;
  static Future<String> getDeviceId();
  static Future<String> getDeviceName();
  static String formatTime(int seconds);
}
```

---

## 🔄 리팩토링 단계

### Phase 1: 파일 분리 (우선순위 높음)
1. ✅ FCMTokenManager 추출
2. ✅ FCMPlatformUtils 추출
3. ✅ FCMNotificationService 추출

### Phase 2: 복잡한 로직 분리 (중간 우선순위)
4. ✅ FCMDeviceApprovalService 추출
5. ✅ FCMIncomingCallHandler 추출

### Phase 3: 메시지 처리 분리 (중간 우선순위)
6. ✅ FCMMessageHandler 추출

### Phase 4: 통합 및 테스트 (마지막)
7. ✅ FCMService 메인 파일 정리
8. ✅ 모든 파일 통합 테스트
9. ✅ 문서화

---

## 📊 예상 결과

### Before (현재)
```
fcm_service.dart: 3,405 줄
├── 44개 메서드
├── 모든 기능이 한 파일에
└── 유지보수 어려움
```

### After (리팩토링 후)
```
fcm/
├── fcm_service.dart: ~150 줄 (Main)
├── fcm_token_manager.dart: ~300 줄
├── fcm_device_approval_service.dart: ~800 줄
├── fcm_message_handler.dart: ~400 줄
├── fcm_notification_service.dart: ~500 줄
├── fcm_incoming_call_handler.dart: ~600 줄
└── fcm_platform_utils.dart: ~200 줄

총 7개 파일, 평균 ~400줄
각 파일은 단일 책임만 가짐
```

---

## ✅ 리팩토링 이점

1. **가독성 향상**
   - 각 파일이 명확한 책임을 가짐
   - 코드 위치를 쉽게 찾을 수 있음

2. **유지보수성 향상**
   - 버그 수정 시 관련 파일만 수정
   - 영향 범위가 명확함

3. **테스트 용이성**
   - 각 서비스를 독립적으로 테스트 가능
   - Mock 객체 사용 용이

4. **재사용성 향상**
   - 다른 프로젝트에서도 개별 모듈 재사용 가능

5. **협업 개선**
   - 여러 개발자가 동시에 작업 가능
   - Merge conflict 감소

---

## ⚠️ 주의사항

1. **기존 코드와의 호환성**
   - 기존 코드를 점진적으로 마이그레이션
   - 한 번에 모든 것을 바꾸지 않음

2. **테스트**
   - 리팩토링 후 모든 기능 테스트 필수
   - 기존 기능이 정상 작동하는지 확인

3. **문서화**
   - 각 서비스의 역할과 사용법 문서화
   - API 변경사항 명시

4. **Import 관리**
   - 순환 참조(Circular dependency) 방지
   - 명확한 의존성 구조 유지

---

## 🎯 시작하기

리팩토링을 시작하시겠습니까?

**Option 1**: Phase 1부터 단계적으로 진행 (권장)
- 가장 독립적인 TokenManager와 PlatformUtils부터 추출

**Option 2**: 전체 리팩토링 한 번에 진행
- 더 빠르지만 리스크가 큼

**Option 3**: 현재 상태 유지
- 새 기능은 별도 파일로 추가

---

## 💡 추천: Phase 1 우선 진행

가장 안전하고 효과적인 방법:

1. **FCMTokenManager 추출** (1시간)
   - 토큰 관리 로직 분리
   - 다른 코드에 영향 최소

2. **FCMPlatformUtils 추출** (30분)
   - 유틸리티 함수 분리
   - 즉시 재사용 가능

3. **테스트 및 검증** (30분)
   - 기존 기능 정상 작동 확인

이후 Phase 2, 3으로 진행 결정

---

어떤 옵션으로 진행하시겠습니까?
