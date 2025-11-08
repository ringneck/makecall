#!/bin/bash

# iOS 빌드 스크립트
# 사용법: ./scripts/build_ios.sh [debug|release]

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 빌드 모드 (기본값: release)
BUILD_MODE="${1:-release}"

echo -e "${GREEN}🚀 iOS 빌드 시작${NC}"
echo -e "${YELLOW}빌드 모드: ${BUILD_MODE}${NC}"
echo ""

# 1. Flutter dependencies 업데이트
echo -e "${GREEN}📦 Flutter dependencies 업데이트...${NC}"
flutter pub get

# 2. iOS Pods 업데이트
echo -e "${GREEN}🍎 CocoaPods dependencies 업데이트...${NC}"
cd ios
pod install --repo-update
cd ..

# 3. Flutter 코드 생성
echo -e "${GREEN}⚙️  Flutter 코드 생성...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs || true

# 4. iOS 빌드
echo -e "${GREEN}🔨 iOS 빌드 중...${NC}"
if [ "$BUILD_MODE" = "release" ]; then
    flutter build ios --release --no-codesign
else
    flutter build ios --debug --no-codesign
fi

echo ""
echo -e "${GREEN}✅ iOS 빌드 완료!${NC}"
echo -e "${YELLOW}빌드 파일 위치: build/ios/iphoneos/Runner.app${NC}"
