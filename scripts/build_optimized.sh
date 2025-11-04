#!/bin/bash

# 🚀 Flutter 최적화 빌드 스크립트
# 지원 플랫폼: iOS, macOS, Web

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 프로젝트 루트로 이동
cd "$(dirname "$0")/.."

echo -e "${BLUE}🚀 Flutter 최적화 빌드 시작${NC}"
echo ""

# 플랫폼 선택
PLATFORM=${1:-"web"}

case $PLATFORM in
  ios)
    echo -e "${YELLOW}📱 iOS 빌드 준비 중...${NC}"
    
    # Podfile.lock 삭제 (버전 충돌 해결)
    if [ -f "ios/Podfile.lock" ]; then
      echo -e "${YELLOW}🗑️  Podfile.lock 삭제 중...${NC}"
      rm -f ios/Podfile.lock
    fi
    
    # Pods 폴더 삭제 (클린 빌드)
    if [ -d "ios/Pods" ]; then
      echo -e "${YELLOW}🗑️  Pods 폴더 삭제 중...${NC}"
      rm -rf ios/Pods
    fi
    
    # Pod 설치
    echo -e "${YELLOW}📦 CocoaPods 설치 중...${NC}"
    cd ios
    pod install --repo-update
    cd ..
    
    # Flutter 빌드 캐시 클리어
    echo -e "${YELLOW}🧹 Flutter 빌드 캐시 클리어 중...${NC}"
    flutter clean
    flutter pub get
    
    # iOS 빌드
    echo -e "${GREEN}🔨 iOS 빌드 중...${NC}"
    flutter build ios --release \
      --dart-define=flutter.inspector.structuredErrors=false \
      --dart-define=debugShowCheckedModeBanner=false
    
    echo -e "${GREEN}✅ iOS 빌드 완료!${NC}"
    ;;
    
  macos)
    echo -e "${YELLOW}💻 macOS 빌드 준비 중...${NC}"
    
    # Podfile.lock 삭제
    if [ -f "macos/Podfile.lock" ]; then
      echo -e "${YELLOW}🗑️  Podfile.lock 삭제 중...${NC}"
      rm -f macos/Podfile.lock
    fi
    
    # Pods 폴더 삭제
    if [ -d "macos/Pods" ]; then
      echo -e "${YELLOW}🗑️  Pods 폴더 삭제 중...${NC}"
      rm -rf macos/Pods
    fi
    
    # Pod 설치
    echo -e "${YELLOW}📦 CocoaPods 설치 중...${NC}"
    cd macos
    pod install --repo-update
    cd ..
    
    # Flutter 빌드 캐시 클리어
    echo -e "${YELLOW}🧹 Flutter 빌드 캐시 클리어 중...${NC}"
    flutter clean
    flutter pub get
    
    # macOS 빌드
    echo -e "${GREEN}🔨 macOS 빌드 중...${NC}"
    flutter build macos --release \
      --dart-define=flutter.inspector.structuredErrors=false \
      --dart-define=debugShowCheckedModeBanner=false
    
    echo -e "${GREEN}✅ macOS 빌드 완료!${NC}"
    ;;
    
  web)
    echo -e "${YELLOW}🌐 Web 빌드 준비 중...${NC}"
    
    # Flutter 빌드 캐시 클리어
    echo -e "${YELLOW}🧹 Flutter 빌드 캐시 클리어 중...${NC}"
    rm -rf build/web .dart_tool/build_cache
    flutter pub get
    
    # Web 빌드 (최적화)
    echo -e "${GREEN}🔨 Web 빌드 중 (최적화)...${NC}"
    flutter build web --release \
      --dart-define=flutter.inspector.structuredErrors=false \
      --dart-define=debugShowCheckedModeBanner=false \
      --web-renderer canvaskit \
      --source-maps
    
    # 빌드 결과 확인
    if [ -d "build/web" ]; then
      BUILD_SIZE=$(du -sh build/web | cut -f1)
      echo -e "${GREEN}✅ Web 빌드 완료!${NC}"
      echo -e "${BLUE}📦 빌드 크기: $BUILD_SIZE${NC}"
      echo -e "${BLUE}📂 빌드 위치: build/web${NC}"
    else
      echo -e "${RED}❌ Web 빌드 실패${NC}"
      exit 1
    fi
    ;;
    
  all)
    echo -e "${YELLOW}🌍 모든 플랫폼 빌드 중...${NC}"
    
    # iOS 빌드
    $0 ios
    
    # macOS 빌드
    $0 macos
    
    # Web 빌드
    $0 web
    
    echo -e "${GREEN}✅ 모든 플랫폼 빌드 완료!${NC}"
    ;;
    
  *)
    echo -e "${RED}❌ 잘못된 플랫폼: $PLATFORM${NC}"
    echo ""
    echo -e "${YELLOW}사용법:${NC}"
    echo -e "  $0 [platform]"
    echo ""
    echo -e "${YELLOW}지원 플랫폼:${NC}"
    echo -e "  ios     - iOS 빌드"
    echo -e "  macos   - macOS 빌드"
    echo -e "  web     - Web 빌드 (기본값)"
    echo -e "  all     - 모든 플랫폼 빌드"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}🎉 빌드 완료!${NC}"
