#!/bin/bash

# 빌드 캐시 정리 스크립트
# 사용법: ./scripts/clean_build.sh [all|ios|macos|android]

set -e

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TARGET="${1:-all}"

echo -e "${GREEN}🧹 빌드 캐시 정리 시작${NC}"
echo -e "${YELLOW}대상: ${TARGET}${NC}"
echo ""

# Flutter 공통 정리
clean_flutter() {
    echo -e "${GREEN}📦 Flutter 캐시 정리...${NC}"
    flutter clean
    rm -rf .dart_tool/
    rm -rf build/
}

# iOS 정리
clean_ios() {
    echo -e "${GREEN}🍎 iOS 빌드 정리...${NC}"
    rm -rf ios/Pods/
    rm -rf ios/.symlinks/
    rm -rf ios/Flutter/Flutter.framework
    rm -rf ios/Flutter/Flutter.podspec
    rm -rf ios/Flutter/App.framework
    rm -rf ios/Flutter/engine
    rm -rf ios/Runner.xcworkspace/xcuserdata/
    rm -rf ios/Runner.xcodeproj/xcuserdata/
    rm -rf ios/Runner.xcodeproj/project.xcworkspace/xcuserdata/
    rm -f ios/Podfile.lock
    echo -e "${YELLOW}iOS Pods 재설치 필요: cd ios && pod install${NC}"
}

# macOS 정리
clean_macos() {
    echo -e "${GREEN}💻 macOS 빌드 정리...${NC}"
    rm -rf macos/Pods/
    rm -rf macos/Flutter/ephemeral/
    rm -rf macos/Runner.xcworkspace/xcuserdata/
    rm -rf macos/Runner.xcodeproj/xcuserdata/
    rm -rf macos/Runner.xcodeproj/project.xcworkspace/xcuserdata/
    rm -f macos/Podfile.lock
    echo -e "${YELLOW}macOS Pods 재설치 필요: cd macos && pod install${NC}"
}

# Android 정리
clean_android() {
    echo -e "${GREEN}🤖 Android 빌드 정리...${NC}"
    rm -rf android/.gradle/
    rm -rf android/build/
    rm -rf android/app/build/
    rm -rf android/app/.cxx/
    rm -rf android/.idea/
}

# 타겟에 따라 정리
case "$TARGET" in
    all)
        clean_flutter
        clean_ios
        clean_macos
        clean_android
        ;;
    ios)
        clean_flutter
        clean_ios
        ;;
    macos)
        clean_flutter
        clean_macos
        ;;
    android)
        clean_flutter
        clean_android
        ;;
    *)
        echo -e "${RED}❌ 잘못된 타겟: ${TARGET}${NC}"
        echo -e "${YELLOW}사용법: ./scripts/clean_build.sh [all|ios|macos|android]${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ 빌드 캐시 정리 완료!${NC}"
echo -e "${YELLOW}다음 명령어를 실행하세요:${NC}"
echo -e "  flutter pub get"
if [ "$TARGET" = "all" ] || [ "$TARGET" = "ios" ]; then
    echo -e "  cd ios && pod install"
fi
if [ "$TARGET" = "all" ] || [ "$TARGET" = "macos" ]; then
    echo -e "  cd macos && pod install"
fi
