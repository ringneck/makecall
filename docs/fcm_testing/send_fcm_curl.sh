#!/bin/bash
# FCM 메시지 발송 - curl 스크립트
# 
# 사용법:
#   1. 기본 사용: ./send_fcm_curl.sh
#   2. FCM 토큰 지정: ./send_fcm_curl.sh YOUR_FCM_TOKEN
#   3. 발신자 정보 지정: ./send_fcm_curl.sh YOUR_FCM_TOKEN "김철수" "010-1234-5678"

set -e

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}🔔 FCM 수신 전화 알림 발송 (curl)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 1. Access Token 생성
echo -e "${YELLOW}📝 Step 1: Access Token 생성 중...${NC}"
ACCESS_TOKEN=$(python3 -c "
import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests
import sys

try:
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    try:
        firebase_admin.initialize_app(cred)
    except ValueError:
        pass
    
    request = google.auth.transport.requests.Request()
    cred.get_access_token(request)
    print(cred.access_token)
except Exception as e:
    print('ERROR: ' + str(e), file=sys.stderr)
    sys.exit(1)
")

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Access Token 생성 실패${NC}"
    echo -e "${RED}   Admin SDK JSON 파일을 확인하세요: /opt/flutter/firebase-admin-sdk.json${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Access Token 생성 완료${NC}"
echo ""

# 2. Project ID 추출
echo -e "${YELLOW}📝 Step 2: Project ID 추출 중...${NC}"
PROJECT_ID=$(python3 -c "
import json
with open('/opt/flutter/firebase-admin-sdk.json') as f:
    data = json.load(f)
    print(data['project_id'])
")

echo -e "${GREEN}✅ Project ID: ${PROJECT_ID}${NC}"
echo ""

# 3. FCM 토큰 확인 또는 입력
if [ -n "$1" ]; then
    FCM_TOKEN="$1"
    echo -e "${GREEN}✅ FCM 토큰 (인자): ${FCM_TOKEN:0:30}...${NC}"
else
    # Firestore에서 활성 토큰 조회
    echo -e "${YELLOW}📝 Step 3: Firestore에서 활성 FCM 토큰 조회 중...${NC}"
    FCM_TOKEN=$(python3 -c "
import firebase_admin
from firebase_admin import credentials, firestore

try:
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    try:
        firebase_admin.initialize_app(cred)
    except ValueError:
        pass
    
    db = firestore.client()
    query = db.collection('fcm_tokens').where('isActive', '==', True).limit(1)
    docs = list(query.stream())
    
    if docs:
        print(docs[0].id)
    else:
        print('NO_TOKEN_FOUND')
except Exception as e:
    print('NO_TOKEN_FOUND')
")

    if [ "$FCM_TOKEN" = "NO_TOKEN_FOUND" ] || [ -z "$FCM_TOKEN" ]; then
        echo -e "${RED}❌ 활성 FCM 토큰을 찾을 수 없습니다${NC}"
        echo -e "${YELLOW}💡 앱을 실행하고 로그인하여 FCM 토큰을 생성하세요${NC}"
        echo ""
        echo -e "${YELLOW}또는 FCM 토큰을 인자로 전달하세요:${NC}"
        echo -e "   ./send_fcm_curl.sh YOUR_FCM_TOKEN"
        exit 1
    fi
    
    echo -e "${GREEN}✅ FCM 토큰 (Firestore): ${FCM_TOKEN:0:30}...${NC}"
fi

echo ""

# 4. 발신자 정보 설정
CALLER_NAME="${2:-김철수}"
CALLER_NUMBER="${3:-010-1234-5678}"

echo -e "${YELLOW}📝 Step 4: 메시지 정보${NC}"
echo -e "   발신자: ${CALLER_NAME}"
echo -e "   번호: ${CALLER_NUMBER}"
echo ""

# 5. FCM 메시지 발송
echo -e "${YELLOW}📝 Step 5: FCM 메시지 발송 중...${NC}"

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": {
      \"token\": \"${FCM_TOKEN}\",
      \"notification\": {
        \"title\": \"${CALLER_NAME}\",
        \"body\": \"${CALLER_NUMBER}\"
      },
      \"data\": {
        \"type\": \"incoming_call\",
        \"caller_name\": \"${CALLER_NAME}\",
        \"caller_number\": \"${CALLER_NUMBER}\",
        \"caller_avatar\": \"\",
        \"callId\": \"call_$(date +%s)\"
      },
      \"android\": {
        \"priority\": \"high\"
      }
    }
  }")

# HTTP 상태 코드 추출
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}📊 발송 결과${NC}"
echo -e "${BLUE}================================================================${NC}"

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ 메시지 발송 성공!${NC}"
    echo ""
    echo -e "${GREEN}응답:${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo -e "${GREEN}🎉 성공적으로 수신 전화 알림을 발송했습니다!${NC}"
    echo -e "${YELLOW}💡 앱을 확인하여 풀스크린이 표시되는지 확인하세요.${NC}"
else
    echo -e "${RED}❌ 메시지 발송 실패 (HTTP ${HTTP_STATUS})${NC}"
    echo ""
    echo -e "${RED}오류 응답:${NC}"
    echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"
    echo ""
    echo -e "${YELLOW}💡 문제 해결:${NC}"
    echo -e "   1. FCM 토큰이 유효한지 확인"
    echo -e "   2. Admin SDK JSON 파일의 권한 확인"
    echo -e "   3. Project ID가 올바른지 확인"
    exit 1
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}📱 다음 단계${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo "1. 앱에서 수신 전화 풀스크린 확인"
echo "2. 애니메이션 효과 확인 (파동, 글로우, 페이드)"
echo "3. 수락/거절 버튼 동작 테스트"
echo ""
echo -e "${YELLOW}🔄 다시 발송하려면:${NC}"
echo "   ./send_fcm_curl.sh"
echo ""
echo -e "${YELLOW}📚 자세한 가이드:${NC}"
echo "   cat docs/fcm_testing/INCOMING_CALL_TEST.md"
echo ""
