#!/bin/bash

# MAKECALL Firebase Functions 설치 스크립트
# Gmail SMTP를 사용한 이메일 인증 시스템 설정

set -e  # 오류 발생 시 스크립트 중단

echo "=================================================="
echo "🚀 MAKECALL Firebase Functions 설치 시작"
echo "=================================================="
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/home/user/flutter_app"

echo -e "${BLUE}📁 프로젝트 디렉토리: $PROJECT_DIR${NC}"
echo ""

# Step 1: Firebase CLI 설치 확인
echo -e "${YELLOW}[1/8] Firebase CLI 확인 중...${NC}"
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI가 설치되어 있지 않습니다.${NC}"
    echo -e "${YELLOW}📦 Firebase CLI 설치 중...${NC}"
    npm install -g firebase-tools
    echo -e "${GREEN}✅ Firebase CLI 설치 완료${NC}"
else
    echo -e "${GREEN}✅ Firebase CLI 이미 설치됨${NC}"
fi
echo ""

# Step 2: Firebase 로그인 확인
echo -e "${YELLOW}[2/8] Firebase 로그인 확인 중...${NC}"
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}📝 Firebase 로그인이 필요합니다.${NC}"
    firebase login
else
    echo -e "${GREEN}✅ Firebase 로그인 확인 완료${NC}"
fi
echo ""

# Step 3: Functions 디렉토리 생성
echo -e "${YELLOW}[3/8] Functions 디렉토리 설정 중...${NC}"
cd "$PROJECT_DIR"

if [ ! -d "functions" ]; then
    echo -e "${YELLOW}📦 Firebase Functions 초기화 중...${NC}"
    firebase init functions --project default
    echo -e "${GREEN}✅ Functions 디렉토리 생성 완료${NC}"
else
    echo -e "${GREEN}✅ Functions 디렉토리 이미 존재${NC}"
fi
echo ""

# Step 4: package.json 복사
echo -e "${YELLOW}[4/8] package.json 설정 중...${NC}"
if [ -f "$SCRIPT_DIR/functions_package.json" ]; then
    cp "$SCRIPT_DIR/functions_package.json" "$PROJECT_DIR/functions/package.json"
    echo -e "${GREEN}✅ package.json 복사 완료${NC}"
else
    echo -e "${RED}❌ functions_package.json 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi
echo ""

# Step 5: index.js 복사
echo -e "${YELLOW}[5/8] index.js 설정 중...${NC}"
if [ -f "$SCRIPT_DIR/functions_index.js" ]; then
    cp "$SCRIPT_DIR/functions_index.js" "$PROJECT_DIR/functions/index.js"
    echo -e "${GREEN}✅ index.js 복사 완료${NC}"
else
    echo -e "${RED}❌ functions_index.js 파일을 찾을 수 없습니다.${NC}"
    exit 1
fi
echo ""

# Step 6: npm 패키지 설치
echo -e "${YELLOW}[6/8] npm 패키지 설치 중...${NC}"
cd "$PROJECT_DIR/functions"
npm install
echo -e "${GREEN}✅ npm 패키지 설치 완료${NC}"
echo ""

# Step 7: Gmail 환경 변수 설정
echo -e "${YELLOW}[7/8] Gmail 환경 변수 설정${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📧 Gmail 계정 정보를 입력해주세요:${NC}"
echo ""

read -p "Gmail 주소 (예: makecall@gmail.com): " GMAIL_EMAIL
read -sp "Gmail 앱 비밀번호 (16자리): " GMAIL_PASSWORD
echo ""
echo ""

if [ -z "$GMAIL_EMAIL" ] || [ -z "$GMAIL_PASSWORD" ]; then
    echo -e "${RED}❌ Gmail 계정 정보가 입력되지 않았습니다.${NC}"
    echo -e "${YELLOW}💡 나중에 수동으로 설정하려면:${NC}"
    echo -e "   firebase functions:config:set gmail.email=\"your-email@gmail.com\""
    echo -e "   firebase functions:config:set gmail.password=\"your-app-password\""
    echo ""
else
    echo -e "${YELLOW}🔧 Firebase Functions Config 설정 중...${NC}"
    firebase functions:config:set gmail.email="$GMAIL_EMAIL"
    firebase functions:config:set gmail.password="$GMAIL_PASSWORD"
    echo -e "${GREEN}✅ Gmail 환경 변수 설정 완료${NC}"
fi
echo ""

# Step 8: Firestore 보안 규칙 복사
echo -e "${YELLOW}[8/8] Firestore 보안 규칙 설정 중...${NC}"
if [ -f "$SCRIPT_DIR/firestore.rules" ]; then
    cp "$SCRIPT_DIR/firestore.rules" "$PROJECT_DIR/firestore.rules"
    echo -e "${GREEN}✅ firestore.rules 복사 완료${NC}"
else
    echo -e "${RED}❌ firestore.rules 파일을 찾을 수 없습니다.${NC}"
fi
echo ""

# 완료 메시지
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Firebase Functions 설치 완료!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}📝 다음 단계:${NC}"
echo ""
echo -e "${BLUE}1. Functions 배포:${NC}"
echo -e "   cd $PROJECT_DIR"
echo -e "   firebase deploy --only functions"
echo ""
echo -e "${BLUE}2. Firestore 보안 규칙 배포:${NC}"
echo -e "   firebase deploy --only firestore:rules"
echo ""
echo -e "${BLUE}3. 로컬 테스트 (선택사항):${NC}"
echo -e "   cd $PROJECT_DIR"
echo -e "   firebase emulators:start"
echo ""

echo -e "${YELLOW}⚠️  중요 사항:${NC}"
echo -e "   - Gmail 앱 비밀번호는 Google 계정 → 보안 → 앱 비밀번호에서 생성"
echo -e "   - 2단계 인증 활성화 필수"
echo -e "   - 하루 500통 이메일 전송 제한 (Gmail 무료 계정)"
echo ""

echo -e "${GREEN}설치 가이드 전체 문서: $SCRIPT_DIR/firebase_functions_setup.md${NC}"
echo ""
