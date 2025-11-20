#!/bin/bash

# 🔍 카카오 로그인 함수 상태 진단 스크립트
# 
# 이 스크립트는 createCustomTokenForKakao 함수의 상태를 진단합니다.

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 카카오 로그인 함수 상태 진단"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Firebase 프로젝트 확인
echo "📋 1. Firebase 프로젝트 확인"
if command -v firebase &> /dev/null; then
    PROJECT_ID=$(firebase projects:list 2>/dev/null | grep -oP 'makecall-\w+' | head -1)
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(grep -oP '"project_id":\s*"\K[^"]+' .firebaserc 2>/dev/null | head -1)
    fi
    
    if [ -n "$PROJECT_ID" ]; then
        echo "   ✅ 프로젝트 ID: $PROJECT_ID"
    else
        echo "   ⚠️ 프로젝트 ID를 찾을 수 없습니다"
        echo "      .firebaserc 파일을 확인하세요"
    fi
else
    echo "   ⚠️ Firebase CLI가 설치되지 않았습니다"
    PROJECT_ID=$(grep -oP '"project_id":\s*"\K[^"]+' .firebaserc 2>/dev/null | head -1)
    if [ -n "$PROJECT_ID" ]; then
        echo "   📝 .firebaserc에서 프로젝트 ID 추출: $PROJECT_ID"
    fi
fi
echo ""

# 2. Functions 코드 존재 확인
echo "📋 2. Functions 코드 존재 확인"
if [ -f "functions/index.js" ]; then
    echo "   ✅ functions/index.js 파일 존재"
    
    if grep -q "createCustomTokenForKakao" functions/index.js; then
        echo "   ✅ createCustomTokenForKakao 함수 정의 확인"
        
        # 함수가 정의된 라인 번호 확인
        LINE_NUM=$(grep -n "createCustomTokenForKakao" functions/index.js | head -1 | cut -d: -f1)
        echo "      → 라인 번호: $LINE_NUM"
        
        # 리전 설정 확인
        REGION=$(grep -oP 'region\s*=\s*"\K[^"]+' functions/index.js | head -1)
        if [ -n "$REGION" ]; then
            echo "   ✅ 리전 설정: $REGION"
        else
            echo "   ⚠️ 리전 설정을 찾을 수 없습니다"
        fi
    else
        echo "   ❌ createCustomTokenForKakao 함수가 정의되지 않았습니다"
    fi
else
    echo "   ❌ functions/index.js 파일이 없습니다"
fi
echo ""

# 3. Firebase Functions 배포 상태 확인
echo "📋 3. Firebase Functions 배포 상태 확인"
echo "   💡 로컬에서는 배포 상태를 확인할 수 없습니다"
echo "   💡 Firebase Console에서 확인하세요:"
echo ""
echo "   🌐 Firebase Console → Functions"
if [ -n "$PROJECT_ID" ]; then
    echo "   🔗 https://console.firebase.google.com/project/$PROJECT_ID/functions"
else
    echo "   🔗 https://console.firebase.google.com/"
fi
echo ""
echo "   ✅ 배포된 함수 목록에서 다음을 확인:"
echo "      - createCustomTokenForKakao 함수 존재 여부"
echo "      - 리전: asia-northeast3 (서울)"
echo "      - 상태: 활성 (Active)"
echo ""

# 4. 일반적인 문제 체크리스트
echo "📋 4. 일반적인 문제 체크리스트"
echo ""
echo "   [ ] Firebase Functions가 배포되었는가?"
echo "       → firebase deploy --only functions:createCustomTokenForKakao"
echo ""
echo "   [ ] 함수가 올바른 리전(asia-northeast3)에 배포되었는가?"
echo "       → Flutter 코드: FirebaseFunctions.instanceFor(region: 'asia-northeast3')"
echo "       → Functions 코드: functions.region('asia-northeast3')"
echo ""
echo "   [ ] IAM 권한이 올바르게 설정되었는가?"
echo "       → Service Account Token Creator"
echo "       → Service Usage Consumer"
echo ""
echo "   [ ] Firebase Functions가 활성화되었는가?"
echo "       → Firebase Console → Build → Functions"
echo ""
echo "   [ ] 청구(Billing)가 활성화되었는가?"
echo "       → Blaze 플랜 필요 (Cloud Functions 사용)"
echo ""

# 5. 함수 테스트 방법
echo "📋 5. 함수 테스트 방법"
echo ""
echo "   A. Firebase Console에서 직접 테스트:"
echo "      1. Firebase Console → Functions"
echo "      2. createCustomTokenForKakao 함수 클릭"
echo "      3. '테스트' 탭에서 다음 데이터로 테스트:"
echo ""
echo "         {"
echo "           \"data\": {"
echo "             \"kakaoUid\": \"test123\","
echo "             \"email\": \"test@example.com\","
echo "             \"displayName\": \"테스트 사용자\""
echo "           }"
echo "         }"
echo ""
echo "   B. curl로 테스트:"
if [ -n "$PROJECT_ID" ]; then
    echo "      curl -X POST \\"
    echo "        https://asia-northeast3-$PROJECT_ID.cloudfunctions.net/createCustomTokenForKakao \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{"
    echo "          \"data\": {"
    echo "            \"kakaoUid\": \"test123\","
    echo "            \"email\": \"test@example.com\","
    echo "            \"displayName\": \"테스트 사용자\""
    echo "          }"
    echo "        }'"
else
    echo "      (프로젝트 ID가 필요합니다)"
fi
echo ""

# 6. 로그 확인 방법
echo "📋 6. 로그 확인 방법"
echo ""
echo "   Firebase Console → Functions → 로그"
if [ -n "$PROJECT_ID" ]; then
    echo "   🔗 https://console.firebase.google.com/project/$PROJECT_ID/functions/logs"
else
    echo "   🔗 https://console.firebase.google.com/"
fi
echo ""
echo "   ✅ 로그에서 확인할 내용:"
echo "      - '🔐 [KAKAO] Creating custom token for user' 메시지"
echo "      - '✅ [KAKAO] Custom token created successfully' 성공 메시지"
echo "      - '❌ [KAKAO] Error creating custom token' 에러 메시지"
echo ""

# 7. 문제 해결 순서
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 문제 해결 순서"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣ Firebase Functions 배포 확인"
echo "   → Firebase Console에서 함수 존재 여부 확인"
echo "   → 없으면: firebase deploy --only functions:createCustomTokenForKakao"
echo ""
echo "2️⃣ 리전 일치 확인"
echo "   → Flutter: instanceFor(region: 'asia-northeast3')"
echo "   → Functions: functions.region('asia-northeast3')"
echo "   → 배포된 함수의 리전 확인"
echo ""
echo "3️⃣ IAM 권한 재확인"
echo "   → Google Cloud Console → IAM"
echo "   → Firebase 서비스 계정 찾기"
echo "   → Service Account Token Creator 역할 확인"
echo ""
echo "4️⃣ Billing 활성화 확인"
echo "   → Google Cloud Console → Billing"
echo "   → Blaze 플랜 활성화 여부 확인"
echo ""
echo "5️⃣ Firebase Console에서 직접 테스트"
echo "   → Functions → createCustomTokenForKakao → 테스트"
echo "   → 로그 확인"
echo ""
echo "6️⃣ Flutter 앱에서 재시도"
echo "   → 카카오 로그인 버튼 클릭"
echo "   → Flutter 콘솔 로그 확인"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 진단 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
