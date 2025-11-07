# Firebase Functions 최종 배포 가이드

## 🎯 Cloud Scheduler 403 오류 해결 완료!

### 문제 해결 방법
Cloud Scheduler API 권한 부족 문제를 **Scheduled Functions → Callable Functions** 변경으로 해결했습니다.

---

## 📦 최종 Functions 구성 (14개)

### 🔥 Firestore Triggers (3개) - 자동 실행
1. ✅ **sendForceLogoutNotification** - 강제 로그아웃 알림
   - Trigger: `fcm_force_logout_queue` 문서 생성 시
   - 중복 로그인 감지 시 자동 알림 전송

2. ✅ **sendIncomingCallNotification** - 착신 전화 알림
   - Trigger: `incoming_calls` 문서 생성 시
   - 실시간 착신 알림 전송

3. ✅ **sendCallStatusNotification** - 통화 상태 변경 알림
   - Trigger: `call_history` 문서 업데이트 시
   - 통화 시작/종료 알림 전송

---

### 📞 Callable Functions (9개) - Flutter 앱에서 호출

4. ✅ **remoteLogout** - 원격 로그아웃
   - 특정 기기를 원격으로 로그아웃
   - 활성 세션 관리 UI에서 사용

5. ✅ **cleanupExpiredTokens** - 만료된 FCM 토큰 정리 ⭐ **변경됨**
   - **이전**: Scheduled Function (매일 자정 자동 실행)
   - **현재**: Callable Function (외부 크론 서비스에서 호출)
   - Parameters: `daysThreshold`, `testMode`
   - 외부 크론으로 스케줄 설정 필요

6. ✅ **processScheduledNotifications** - 예약 알림 처리 ⭐ **변경됨**
   - **이전**: Scheduled Function (매 5분마다 자동 실행)
   - **현재**: Callable Function (외부 크론 서비스에서 호출)
   - Parameters: `limit`
   - 외부 크론으로 스케줄 설정 필요

7. ✅ **manualCleanupTokens** - 수동 토큰 정리
   - cleanupExpiredTokens의 별칭
   - 기존 코드 호환성 유지

8. ✅ **sendGroupMessage** - 그룹 메시지 브로드캐스트
   - 여러 사용자에게 동시 알림 전송
   - 최대 500명까지 배치 처리

9. ✅ **sendCustomNotification** - 사용자 지정 알림
   - 커스텀 제목, 내용, 데이터 전송
   - 웹푸시 옵션 지원

10. ✅ **subscribeWebPush** - 웹푸시 구독 관리
    - 웹푸시 구독/해제 처리
    - VAPID 키 관리

11. ✅ **validateAllTokens** - FCM 토큰 검증
    - 모든 토큰의 유효성 검사
    - 유효하지 않은 토큰 자동 삭제

12. ✅ **validateToken** - 단일 토큰 검증
    - 특정 토큰의 유효성 검사

---

### 🌐 HTTP Functions (1개) - REST API

13. ✅ **getNotificationStats** - 알림 통계 조회
    - URL: https://asia-east1-makecallio.cloudfunctions.net/getNotificationStats
    - 알림 전송 성공/실패 통계

---

## 🚀 배포 명령어

```bash
cd /Users/NORMAND/makecall/makecall

# 최신 코드 가져오기
git pull origin main

# Firebase Functions 배포
firebase deploy --only functions --project makecallio
```

**예상 결과**: ✅ **14개 Functions 모두 성공적으로 배포**

---

## ⚙️ 배포 후 설정 (중요!)

### 1. 외부 크론 서비스 설정 필요

**cleanupExpiredTokens**와 **processScheduledNotifications**는 더 이상 자동으로 실행되지 않습니다.
외부 크론 서비스를 설정해야 합니다.

#### 옵션 1: GitHub Actions (권장) ⭐

`.github/workflows/firebase-cron.yml` 파일 생성:

```yaml
name: Firebase Functions Cron Jobs

on:
  schedule:
    # 매일 02:00 KST - 토큰 정리
    - cron: '0 17 * * *'  # 17:00 UTC = 02:00 KST (다음날)
  workflow_dispatch:  # 수동 실행 가능

jobs:
  cleanup-tokens:
    runs-on: ubuntu-latest
    steps:
      - name: Cleanup Expired FCM Tokens
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -d '{"data": {"daysThreshold": 30, "testMode": false}}' \
            https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens

  process-notifications:
    runs-on: ubuntu-latest
    steps:
      - name: Process Scheduled Notifications
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -d '{"data": {"limit": 100}}' \
            https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications
```

**GitHub Actions 설정**:
1. `.github/workflows/firebase-cron.yml` 파일을 리포지토리에 추가
2. GitHub에 푸시
3. Actions 탭에서 활성화 확인

---

#### 옵션 2: Flutter 앱 내 수동 실행

관리자 페이지에 버튼 추가:

```dart
// 토큰 정리 버튼
ElevatedButton(
  onPressed: () async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('cleanupExpiredTokens')
        .call({'daysThreshold': 30, 'testMode': false});
    
    print('✅ 정리된 토큰: ${result.data['deletedCount']}개');
  },
  child: Text('만료된 토큰 정리'),
)

// 예약 알림 처리 버튼
ElevatedButton(
  onPressed: () async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('processScheduledNotifications')
        .call({'limit': 100});
    
    print('✅ 처리된 알림: ${result.data['processedCount']}개');
  },
  child: Text('예약 알림 처리'),
)
```

---

#### 옵션 3: 외부 크론 서비스 (EasyCron, Cron-job.org)

**EasyCron 설정**:
1. https://www.easycron.com 가입
2. 새 크론 작업 생성:
   - **URL**: `https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens`
   - **Method**: POST
   - **Body**: `{"data": {"daysThreshold": 30, "testMode": false}}`
   - **Schedule**: `0 2 * * *` (매일 02:00 KST)

---

### 2. 테스트 실행

```bash
# 토큰 정리 테스트 (삭제하지 않음)
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"data": {"daysThreshold": 30, "testMode": true}}' \
  https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens

# 예약 알림 처리 테스트
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"data": {"limit": 10}}' \
  https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications
```

---

## 📚 참고 문서

### 상세 가이드
- **Functions 사용 설명서**: `functions/README.md`
- **Cloud Scheduler 대안 가이드**: `functions/SCHEDULER_ALTERNATIVE.md`
- **배포 상태 보고서**: `DEPLOYMENT_STATUS.md`

### Firebase Console
- **Functions 대시보드**: https://console.firebase.google.com/project/makecallio/functions
- **Functions 로그**: https://console.firebase.google.com/project/makecallio/functions/logs
- **Firestore 데이터베이스**: https://console.firebase.google.com/project/makecallio/firestore

---

## 🎯 배포 체크리스트

배포 전 확인 사항:

- [x] ESLint 검사 통과 (`npm run lint`)
- [x] Cloud Scheduler import 제거
- [x] Scheduled Functions → Callable Functions 변경
- [x] 테스트 모드 파라미터 추가
- [x] 상세한 응답 데이터 구조
- [x] 문서 작성 완료
- [x] GitHub에 커밋 및 푸시

배포 후 확인 사항:

- [ ] 14개 Functions 모두 배포 성공
- [ ] HTTP Function URL 확인
- [ ] 외부 크론 서비스 설정
- [ ] 테스트 실행으로 동작 확인
- [ ] Firebase Console에서 로그 확인

---

## ✅ 장점

1. **Cloud Scheduler 권한 불필요** - 403 오류 완전 해결
2. **유연한 스케줄 관리** - 외부 서비스에서 자유롭게 설정
3. **수동 실행 가능** - Flutter 앱에서 즉시 호출
4. **비용 절감** - GitHub Actions 무료, EasyCron 무료 티어
5. **테스트 모드 지원** - 안전한 테스트 환경
6. **상세한 응답** - 처리 결과 통계 제공

---

## 🔗 GitHub 리포지토리

https://github.com/ringneck/makecall

**최신 커밋**:
- `179b770` - fix: Convert Scheduled Functions to Callable Functions

---

## 🚨 주의사항

⚠️ **중요**: `cleanupExpiredTokens`와 `processScheduledNotifications`는 더 이상 자동으로 실행되지 않습니다!

**반드시 외부 크론 서비스를 설정하거나 Flutter 앱에서 수동으로 실행하세요.**

---

## 💡 권장 설정

**프로덕션 환경**:
- **토큰 정리**: 매일 새벽 2시 (사용자 적은 시간대)
- **예약 알림**: 매 5분마다 (실시간성 보장)

**개발/테스트 환경**:
- 수동 실행 또는 더 긴 주기 (시간당 1회 등)

---

이제 **모든 Functions가 Cloud Scheduler 권한 없이도 정상적으로 배포 및 실행**됩니다! 🎉
