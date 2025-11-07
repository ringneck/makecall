# Firebase Functions - Cloud Scheduler 대안 가이드

## 문제 상황

Firebase Cloud Scheduler API에 대한 권한 부족으로 Scheduled Functions 배포가 실패하는 경우:

```
Error: Request to https://cloudscheduler.googleapis.com/v1/projects/makecallio/locations/asia-east1/jobs 
had HTTP Error: 403, The caller does not have permission
```

## 해결 방법

모든 Scheduled Functions를 **Callable Functions**로 변경하여 외부 크론 서비스에서 호출하도록 구성합니다.

---

## 변경된 Functions

### 1. cleanupExpiredTokens (만료된 FCM 토큰 정리)

**이전**: Scheduled Function (매일 자정 자동 실행)
**현재**: Callable Function (외부에서 호출)

**호출 방법**:

```dart
// Flutter 앱에서 호출
final result = await FirebaseFunctions.instance
    .httpsCallable('cleanupExpiredTokens')
    .call({
      'daysThreshold': 30,  // 30일 이상 미사용 토큰 삭제
      'testMode': false,    // 실제 삭제 수행
    });

print('✅ 정리된 토큰: ${result.data['deletedCount']}개');
print('📊 총 토큰: ${result.data['totalTokens']}개');
```

**Parameters**:
- `daysThreshold` (number): 토큰 만료 기준 일수 (기본값: 30)
- `testMode` (boolean): 테스트 모드 (삭제하지 않고 개수만 반환)

**Response**:
```json
{
  "success": true,
  "deletedCount": 15,
  "totalTokens": 15,
  "testMode": false
}
```

---

### 2. processScheduledNotifications (예약 알림 처리)

**이전**: Scheduled Function (매 5분마다 자동 실행)
**현재**: Callable Function (외부에서 호출)

**호출 방법**:

```dart
// Flutter 앱에서 호출
final result = await FirebaseFunctions.instance
    .httpsCallable('processScheduledNotifications')
    .call({
      'limit': 100,  // 한 번에 처리할 알림 개수
    });

print('✅ 처리된 알림: ${result.data['processedCount']}개');
print('📊 성공: ${result.data['successCount']}, 실패: ${result.data['failureCount']}');
```

**Parameters**:
- `limit` (number): 한 번에 처리할 알림 개수 (기본값: 100)

**Response**:
```json
{
  "success": true,
  "processedCount": 5,
  "totalFound": 5,
  "successCount": 5,
  "failureCount": 0
}
```

---

## 외부 크론 서비스 설정

### Option 1: GitHub Actions (권장)

`.github/workflows/firebase-cron.yml` 파일 생성:

```yaml
name: Firebase Functions Cron Jobs

on:
  schedule:
    # 매일 02:00 KST (17:00 UTC 전날) - 토큰 정리
    - cron: '0 17 * * *'
    # 매 5분마다 - 예약 알림 처리
    - cron: '*/5 * * * *'
  workflow_dispatch:  # 수동 실행 가능

jobs:
  cleanup-tokens:
    runs-on: ubuntu-latest
    if: github.event.schedule == '0 17 * * *'
    steps:
      - name: Cleanup Expired FCM Tokens
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ secrets.FIREBASE_TOKEN }}" \
            -d '{"data": {"daysThreshold": 30, "testMode": false}}' \
            https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens

  process-notifications:
    runs-on: ubuntu-latest
    if: github.event.schedule == '*/5 * * * *'
    steps:
      - name: Process Scheduled Notifications
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${{ secrets.FIREBASE_TOKEN }}" \
            -d '{"data": {"limit": 100}}' \
            https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications
```

**GitHub Secrets 설정**:
1. Firebase 인증 토큰 생성:
   ```bash
   firebase login:ci
   ```
2. GitHub 리포지토리 → Settings → Secrets → New repository secret
3. Name: `FIREBASE_TOKEN`
4. Value: 생성된 토큰

---

### Option 2: Cloud Run Jobs

1. **Cloud Run Job 생성** (토큰 정리):
   ```bash
   gcloud run jobs create cleanup-tokens \
     --image=gcr.io/cloudrun/hello \
     --region=asia-east1 \
     --execute-now \
     --command="curl" \
     --args="-X,POST,-H,Content-Type: application/json,-d,{\"data\":{\"daysThreshold\":30}},https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens"
   ```

2. **Cloud Scheduler로 스케줄 설정**:
   ```bash
   gcloud scheduler jobs create http cleanup-tokens-scheduler \
     --location=asia-east1 \
     --schedule="0 2 * * *" \
     --time-zone="Asia/Seoul" \
     --uri="https://asia-east1-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/makecallio/jobs/cleanup-tokens:run" \
     --http-method=POST \
     --oauth-service-account-email=makecallio@appspot.gserviceaccount.com
   ```

---

### Option 3: Vercel Cron Jobs

`vercel.json` 파일 생성:

```json
{
  "crons": [
    {
      "path": "/api/cleanup-tokens",
      "schedule": "0 2 * * *"
    },
    {
      "path": "/api/process-notifications",
      "schedule": "*/5 * * * *"
    }
  ]
}
```

`api/cleanup-tokens.js`:
```javascript
export default async function handler(req, res) {
  const response = await fetch(
    'https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: { daysThreshold: 30, testMode: false } })
    }
  );
  
  const result = await response.json();
  res.status(200).json(result);
}
```

---

### Option 4: 외부 크론 서비스 (EasyCron, Cron-job.org 등)

**EasyCron 설정 예시**:
1. https://www.easycron.com 가입
2. 새 크론 작업 생성:
   - **URL**: `https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens`
   - **Method**: POST
   - **Body**: `{"data": {"daysThreshold": 30, "testMode": false}}`
   - **Schedule**: `0 2 * * *` (매일 02:00)

---

## Flutter 앱에서 수동 실행

관리자 페이지에서 버튼을 통해 수동으로 실행:

```dart
class AdminPage extends StatelessWidget {
  Future<void> _manualCleanup() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('cleanupExpiredTokens')
          .call({'daysThreshold': 30, 'testMode': false});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.data['deletedCount']}개 토큰 정리 완료'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 토큰 정리 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processNotifications() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('processScheduledNotifications')
          .call({'limit': 100});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.data['processedCount']}개 알림 처리 완료'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌알림 처리 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('관리자 페이지')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _manualCleanup,
            child: Text('만료된 토큰 정리'),
          ),
          ElevatedButton(
            onPressed: _processNotifications,
            child: Text('예약 알림 처리'),
          ),
        ],
      ),
    );
  }
}
```

---

## 권장 설정

**프로덕션 환경**:
- **토큰 정리**: 매일 새벽 2시 (사용자 적은 시간대)
- **예약 알림**: 매 5분마다 (실시간성 보장)

**개발/테스트 환경**:
- 수동 실행 또는 더 긴 주기 (시간당 1회 등)

---

## 테스트

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

## 모니터링

Firebase Console에서 Functions 로그 확인:
https://console.firebase.google.com/project/makecallio/functions/logs

**로그 필터**:
```
resource.labels.function_name="cleanupExpiredTokens"
resource.labels.function_name="processScheduledNotifications"
```

---

## 장점

✅ **Cloud Scheduler 권한 불필요** - 403 오류 회피
✅ **유연한 스케줄 관리** - 외부 서비스에서 자유롭게 설정
✅ **수동 실행 가능** - Flutter 앱에서 즉시 호출 가능
✅ **비용 절감** - 대부분의 외부 크론 서비스는 무료
✅ **테스트 모드 지원** - 안전한 테스트 환경

---

## 주의사항

⚠️ **보안**: 민감한 Functions는 Firebase Authentication 필수
⚠️ **인증**: 외부 크론 서비스 사용 시 적절한 인증 설정
⚠️ **모니터링**: 실행 여부와 결과를 주기적으로 확인
⚠️ **타임존**: 스케줄 설정 시 시간대 주의 (KST vs UTC)

---

## 문제 해결

**403 Forbidden 오류**:
- Firebase Authentication 토큰 확인
- 서비스 계정 권한 확인

**타임아웃**:
- `limit` 파라미터로 처리량 조절
- 여러 번 나누어 실행

**실행 안 됨**:
- 크론 설정 확인 (시간대, 일정)
- Functions 로그 확인
- 네트워크 연결 확인
