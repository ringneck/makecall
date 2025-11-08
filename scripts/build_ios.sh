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

# 사용 가능한 시뮬레이터 자동 선택
SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -o '\[.*\]' | sed 's/\[//;s/\]//')

if [ "$BUILD_MODE" = "release" ]; then
    if [ -z "$SIMULATOR_ID" ]; then
        echo -e "${YELLOW}⚠️  시뮬레이터를 찾을 수 없습니다. 실제 디바이스용으로 빌드합니다.${NC}"
        flutter build ios --release --no-codesign
    else
        echo -e "${GREEN}✓ 시뮬레이터용으로 빌드: $SIMULATOR_ID${NC}"
        flutter build ios --release --simulator
    fi
else
    if [ -z "$SIMULATOR_ID" ]; then
        echo -e "${YELLOW}⚠️  시뮬레이터를 찾을 수 없습니다. 실제 디바이스용으로 빌드합니다.${NC}"
        flutter build ios --debug --no-codesign
    else
        echo -e "${GREEN}✓ 시뮬레이터용으로 빌드: $SIMULATOR_ID${NC}"
        flutter build ios --debug --simulator
    fi
fi

echo ""
echo -e "${GREEN}✅ iOS 빌드 완료!${NC}"
echo -e "${YELLOW}빌드 파일 위치: build/ios/iphoneos/Runner.app${NC}"
