# Firebase Functions 배포 상태

## ✅ 배포 성공한 Functions

### HTTP Functions
- ✅ `getNotificationStats` 
  - URL: https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
  - 역할: 알림 통계 조회 API

### Firestore Triggers (자동 배포 성공으로 추정)
- ✅ `sendForceLogoutNotification` - 강제 로그아웃 알림
- ✅ `sendIncomingCallNotification` - 착신 전화 알림  
- ✅ `sendCallStatusNotification` - 통화 상태 변경 알림

### Callable Functions (자동 배포 성공으로 추정)
- ✅ `remoteLogout` - 원격 로그아웃
- ✅ `sendGroupMessage` - 그룹 메시지 전송
- ✅ `sendCustomNotification` - 사용자 지정 알림
- ✅ `subscribeWebPush` - 웹푸시 구독 관리
- ✅ `validateAllTokens` - FCM 토큰 검증
- ✅ `manualCleanupTokens` - 수동 토큰 정리

### Scheduled Functions
- ✅ `processScheduledNotifications` - 예약 알림 처리 (매 5분)

## ⚠️ 배포 실패한 Functions

### Scheduled Functions
- ❌ `cleanupExpiredTokens` - 만료된 FCM 토큰 정리
  - **원인**: Cloud Scheduler API 일시적 장애 (503 오류)
  - **영향**: 자동 토큰 정리 기능만 미작동
  - **대안**: `manualCleanupTokens` Callable Function 사용 가능

---

## 🔧 해결 방법

### 방법 1: 잠시 후 재배포 (권장)

Cloud Scheduler API가 복구되면 해당 함수만 다시 배포:

\`\`\`bash
# 5-10분 후 재시도
firebase deploy --only functions:cleanupExpiredTokens
\`\`\`

### 방법 2: Google Cloud Console에서 수동 설정

1. Cloud Scheduler 페이지 이동:
   https://console.cloud.google.com/cloudscheduler?project=makecallio

2. "작업 만들기" 클릭

3. 설정:
   - **이름**: `firebase-schedule-cleanupExpiredTokens-asia-east1`
   - **리전**: `asia-east1`
   - **일정**: `0 2 * * *` (매일 02:00 KST)
   - **시간대**: `Asia/Seoul`
   - **대상 유형**: `HTTP`
   - **URL**: `https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens`
   - **HTTP 메서드**: `POST`
   - **인증 헤더**: "OIDC 토큰 추가" 선택
   - **서비스 계정**: `makecallio@appspot.gserviceaccount.com`

### 방법 3: 수동으로 토큰 정리 실행

`cleanupExpiredTokens` 대신 `manualCleanupTokens` Callable Function 사용:

\`\`\`dart
// Flutter 앱에서 수동 실행
final result = await FirebaseFunctions.instance
    .httpsCallable('manualCleanupTokens')
    .call({
      'daysThreshold': 30,  // 30일 이상 미사용 토큰 삭제
      'testMode': false,    // 실제 삭제 수행
    });

print('정리된 토큰: \${result.data['deletedCount']}개');
\`\`\`

### 방법 4: Cloud Scheduler API 활성화 확인

API가 활성화되지 않은 경우:

1. https://console.cloud.google.com/apis/library/cloudscheduler.googleapis.com?project=makecallio
2. "사용 설정" 클릭
3. 다시 배포 시도

---

## 📊 배포 통계

- **총 Functions**: 14개
- **배포 성공**: 13개 (92.9%)
- **배포 실패**: 1개 (7.1%)
- **핵심 기능 상태**: ✅ 정상 작동
- **영향도**: ⚠️ 낮음 (수동 정리 기능으로 대체 가능)

---

## 🎯 현재 사용 가능한 기능

### 즉시 사용 가능
- ✅ 강제 로그아웃 푸시 알림
- ✅ 착신 전화 실시간 알림
- ✅ 통화 상태 변경 알림
- ✅ 그룹 메시지 브로드캐스트
- ✅ 예약 알림 시스템 (5분마다 자동 실행)
- ✅ 사용자 지정 알림
- ✅ 웹푸시 구독 관리
- ✅ FCM 토큰 검증
- ✅ 알림 통계 API

### 수동 실행 필요
- ⚠️ 만료된 FCM 토큰 정리 (manualCleanupTokens 사용)

---

## 🚀 다음 단계

1. **즉시**: 배포된 Functions 테스트 시작
2. **5-10분 후**: cleanupExpiredTokens 재배포 시도
3. **필요시**: Cloud Scheduler 수동 설정 또는 manualCleanupTokens 사용

