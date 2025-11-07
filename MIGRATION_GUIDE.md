# Firebase Functions 마이그레이션 가이드

## 🚨 문제: Scheduled → Callable 변환 불가

Firebase는 기존 Scheduled Function을 Callable Function으로 직접 변환할 수 없습니다.

```
Error: [cleanupExpiredTokens(asia-east1)] Changing from a scheduled function to a 
callable function is not allowed. Please delete your function and create a new one instead.
```

---

## ✅ 해결 방법 (3단계)

### 1단계: 기존 Scheduled Functions 삭제

```bash
cd /Users/NORMAND/makecall/makecall

# cleanupExpiredTokens 삭제
firebase functions:delete cleanupExpiredTokens --project makecallio

# processScheduledNotifications 삭제
firebase functions:delete processScheduledNotifications --project makecallio
```

각 함수 삭제 시 확인 메시지가 나오면 `y` 입력하여 확인합니다.

---

### 2단계: 새로운 Callable Functions 배포

```bash
# 전체 Functions 배포 (새로운 Callable 버전으로 배포됨)
firebase deploy --only functions --project makecallio
```

또는 개별적으로:

```bash
firebase deploy --only functions:cleanupExpiredTokens --project makecallio
firebase deploy --only functions:processScheduledNotifications --project makecallio
```

---

### 3단계: 배포 확인

```bash
# Functions 목록 확인
firebase functions:list --project makecallio
```

---

## 🔧 대안: 다운타임 최소화 전략

기존 함수를 삭제하면 짧은 시간 동안 서비스가 중단됩니다. 이를 최소화하려면:

### 옵션 A: 새 이름으로 배포 후 기존 함수 삭제

**1단계: index.js에서 함수 이름 변경**

```javascript
// cleanupExpiredTokens → cleanupExpiredTokensV2
exports.cleanupExpiredTokensV2 = onCall(
    {region: "asia-east1"},
    async (request) => {
      // ... 기존 로직
    }
);

// processScheduledNotifications → processScheduledNotificationsV2
exports.processScheduledNotificationsV2 = onCall(
    {region: "asia-east1"},
    async (request) => {
      // ... 기존 로직
    }
);
```

**2단계: 새 함수 배포**

```bash
firebase deploy --only functions:cleanupExpiredTokensV2,processScheduledNotificationsV2 --project makecallio
```

**3단계: 기존 함수 삭제**

```bash
firebase functions:delete cleanupExpiredTokens --project makecallio
firebase functions:delete processScheduledNotifications --project makecallio
```

**4단계: 함수 이름 원래대로 복원**

```javascript
// V2 제거하고 원래 이름으로 변경
exports.cleanupExpiredTokens = onCall(...);
exports.processScheduledNotifications = onCall(...);
```

**5단계: 재배포 및 V2 삭제**

```bash
firebase deploy --only functions:cleanupExpiredTokens,processScheduledNotifications --project makecallio
firebase functions:delete cleanupExpiredTokensV2 --project makecallio
firebase functions:delete processScheduledNotificationsV2 --project makecallio
```

---

### 옵션 B: 빠른 삭제 후 재배포 (권장)

대부분의 경우 다운타임이 1-2분 정도이므로, 간단하게 삭제 후 재배포하는 것이 더 효율적입니다:

```bash
cd /Users/NORMAND/makecall/makecall

# 1. 기존 함수 삭제
firebase functions:delete cleanupExpiredTokens --project makecallio --force
firebase functions:delete processScheduledNotifications --project makecallio --force

# 2. 즉시 재배포
firebase deploy --only functions:cleanupExpiredTokens,processScheduledNotifications --project makecallio
```

---

## 📋 전체 마이그레이션 스크립트

```bash
#!/bin/bash

PROJECT_ID="makecallio"
FUNCTIONS_DIR="/Users/NORMAND/makecall/makecall"

cd $FUNCTIONS_DIR

echo "🗑️  1단계: 기존 Scheduled Functions 삭제..."
firebase functions:delete cleanupExpiredTokens --project $PROJECT_ID --force
firebase functions:delete processScheduledNotifications --project $PROJECT_ID --force

echo "⏳ 2단계: 5초 대기..."
sleep 5

echo "🚀 3단계: 새로운 Callable Functions 배포..."
firebase deploy --only functions --project $PROJECT_ID

echo "✅ 마이그레이션 완료!"
echo ""
echo "📊 Functions 목록 확인:"
firebase functions:list --project $PROJECT_ID
```

위 스크립트를 `migrate.sh`로 저장하고 실행:

```bash
chmod +x migrate.sh
./migrate.sh
```

---

## 🧪 배포 후 테스트

```bash
# cleanupExpiredTokens 테스트
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"data": {"daysThreshold": 30, "testMode": true}}' \
  https://asia-east1-makecallio.cloudfunctions.net/cleanupExpiredTokens

# processScheduledNotifications 테스트
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"data": {"limit": 10}}' \
  https://asia-east1-makecallio.cloudfunctions.net/processScheduledNotifications
```

---

## ⚠️ 주의사항

1. **다운타임**: 함수 삭제 후 재배포까지 1-2분 소요
2. **예약 알림**: 마이그레이션 중 예약 알림 처리가 잠시 중단될 수 있음
3. **외부 크론**: 마이그레이션 완료 후 외부 크론 서비스 URL 확인

---

## 🎯 권장 진행 순서

**개발/테스트 환경이 없는 경우 (프로덕션 직접 마이그레이션)**:

1. **사용자 적은 시간대 선택** (새벽 2-4시)
2. **기존 함수 삭제** (30초)
3. **새 함수 배포** (1-2분)
4. **테스트 실행** (30초)
5. **외부 크론 설정** (GitHub Actions 등)

**총 소요 시간**: 약 3-5분

---

## 🔗 관련 문서

- Firebase Functions 삭제: https://firebase.google.com/docs/functions/manage-functions#delete_functions
- Functions 배포: https://firebase.google.com/docs/functions/manage-functions#deploy_functions

---

이제 다음 명령어를 실행하세요:

```bash
cd /Users/NORMAND/makecall/makecall

# 기존 함수 삭제 (--force는 확인 없이 삭제)
firebase functions:delete cleanupExpiredTokens --project makecallio --force
firebase functions:delete processScheduledNotifications --project makecallio --force

# 새 함수 배포
firebase deploy --only functions --project makecallio
```
