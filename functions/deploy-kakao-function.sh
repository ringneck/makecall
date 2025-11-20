#!/bin/bash

# 카카오 로그인 Firebase Function 배포 스크립트
# 사용법: ./deploy-kakao-function.sh

echo "🚀 카카오 로그인 Firebase Function 배포 시작..."
echo ""

# 1. Firebase 프로젝트 확인
echo "📋 Firebase 프로젝트 확인 중..."
firebase projects:list

echo ""
echo "현재 프로젝트: makecallio"
echo ""

# 2. Functions 디렉토리로 이동
cd "$(dirname "$0")" || exit 1

# 3. 의존성 설치 확인
if [ ! -d "node_modules" ]; then
    echo "📦 의존성 설치 중..."
    npm install
fi

# 4. ESLint 검사
echo ""
echo "🔍 코드 검사 중..."
npm run lint || {
    echo "⚠️  ESLint 경고가 있지만 계속 진행합니다..."
}

# 5. createCustomTokenForKakao 함수만 배포
echo ""
echo "🚀 createCustomTokenForKakao 함수 배포 중..."
firebase deploy --only functions:createCustomTokenForKakao --force

# 6. 배포 결과 확인
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 배포 완료!"
    echo ""
    echo "📊 배포된 함수 확인:"
    firebase functions:list --filter "createCustomTokenForKakao"
    echo ""
    echo "💡 다음 단계:"
    echo "  1. Flutter 앱을 재시작하세요"
    echo "  2. 카카오 로그인을 테스트하세요"
    echo "  3. 문제가 있다면 로그를 확인하세요:"
    echo "     firebase functions:log --only createCustomTokenForKakao"
else
    echo ""
    echo "❌ 배포 실패!"
    echo "다음을 확인하세요:"
    echo "  1. Firebase CLI 로그인 상태: firebase login"
    echo "  2. 프로젝트 권한 확인"
    echo "  3. 네트워크 연결 확인"
fi
