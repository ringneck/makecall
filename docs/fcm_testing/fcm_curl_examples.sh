#!/bin/bash
# FCM 테스트를 위한 curl 명령어 예제

# 사용법:
# 1. YOUR_SERVER_KEY를 Firebase Console에서 가져온 Server Key로 변경
# 2. YOUR_FCM_TOKEN을 테스트할 기기의 FCM 토큰으로 변경
# 3. 원하는 예제 실행

SERVER_KEY="YOUR_SERVER_KEY"
FCM_TOKEN="YOUR_FCM_TOKEN"

echo "======================================"
echo "FCM 테스트 curl 명령어 예제"
echo "======================================"
echo ""
echo "⚠️  사용 전 수정 필요:"
echo "1. SERVER_KEY 변경 (Firebase Console → Project Settings → Cloud Messaging)"
echo "2. FCM_TOKEN 변경 (앱 로그 또는 Firestore에서 확인)"
echo ""

# 예제 1: 기본 알림
echo "예제 1: 기본 테스트 알림"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "$FCM_TOKEN",
    "notification": {
      "title": "테스트 알림",
      "body": "FCM 푸시 알림 테스트입니다",
      "sound": "default"
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

# 예제 2: 수신 전화 알림
echo "예제 2: 수신 전화 알림"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "$FCM_TOKEN",
    "notification": {
      "title": "📞 수신 전화",
      "body": "010-1234-5678에서 전화가 왔습니다",
      "sound": "default"
    },
    "data": {
      "type": "incoming_call",
      "phoneNumber": "010-1234-5678",
      "callId": "call_12345"
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

# 예제 3: 부재중 전화 알림
echo "예제 3: 부재중 전화 알림"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "$FCM_TOKEN",
    "notification": {
      "title": "📵 부재중 전화",
      "body": "010-9876-5432님의 부재중 전화 1건",
      "sound": "default",
      "badge": "1"
    },
    "data": {
      "type": "missed_call",
      "phoneNumber": "010-9876-5432"
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

# 예제 4: 데이터 전용 메시지 (알림 없음)
echo "예제 4: 데이터 전용 메시지"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "$FCM_TOKEN",
    "data": {
      "type": "background_sync",
      "action": "sync_contacts",
      "timestamp": "1640000000000"
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

# 예제 5: Android 전용 옵션
echo "예제 5: Android 전용 옵션"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "$FCM_TOKEN",
    "notification": {
      "title": "고급 알림",
      "body": "Android 전용 옵션이 적용되었습니다"
    },
    "android": {
      "priority": "high",
      "notification": {
        "sound": "default",
        "channel_id": "high_importance",
        "color": "#2196F3",
        "icon": "ic_notification",
        "click_action": "FLUTTER_NOTIFICATION_CLICK"
      }
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

# 예제 6: 다중 기기 발송
echo "예제 6: 다중 기기 발송"
echo "------------------------"
cat << 'EOF'
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "registration_ids": [
      "$FCM_TOKEN_1",
      "$FCM_TOKEN_2",
      "$FCM_TOKEN_3"
    ],
    "notification": {
      "title": "그룹 알림",
      "body": "모든 기기에 동시 발송"
    },
    "priority": "high"
  }'
EOF
echo ""
echo ""

echo "======================================"
echo "💡 참고사항"
echo "======================================"
echo "1. Server Key는 Firebase Console에서 확인:"
echo "   Project Settings → Cloud Messaging → Server key"
echo ""
echo "2. FCM 토큰은 앱 실행 시 로그에서 확인:"
echo "   ✅ FCM 토큰 획득: eFG3hD9k2L7mP1qR4sT6..."
echo ""
echo "3. 또는 Firestore에서 확인:"
echo "   fcm_tokens 컬렉션 → 문서 ID가 토큰"
echo ""
echo "4. 실제 명령 실행 시:"
echo "   - \$SERVER_KEY를 실제 키로 변경"
echo "   - \$FCM_TOKEN을 실제 토큰으로 변경"
echo "   - 작은따옴표 제거 후 실행"
echo ""
