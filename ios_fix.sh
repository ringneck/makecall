#!/bin/bash

# iOS 빌드 오류 자동 수정 스크립트
# Module 'audioplayers_darwin' not found 해결

echo ""
echo "======================================================================"
echo "🔧 iOS 빌드 오류 자동 수정 스크립트"
echo "======================================================================"
echo ""
echo "⚠️  주의: 이 스크립트는 로컬 Mac에서 실행해야 합니다!"
echo ""

# Flutter 프로젝트 디렉토리 확인
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 오류: Flutter 프로젝트 루트 디렉토리에서 실행하세요"
    echo "   현재 위치: $(pwd)"
    exit 1
fi

echo "✅ Flutter 프로젝트 확인됨"
echo ""

# 1단계: Flutter Clean
echo "1️⃣  Flutter Clean 실행 중..."
flutter clean
echo "✅ Flutter Clean 완료"
echo ""

# 2단계: Flutter Pub Get
echo "2️⃣  Flutter Dependencies 재설치 중..."
flutter pub get
echo "✅ Dependencies 재설치 완료"
echo ""

# 3단계: iOS 디렉토리 확인
if [ ! -d "ios" ]; then
    echo "❌ 오류: ios 디렉토리가 없습니다"
    exit 1
fi

cd ios

# 4단계: 기존 Pods 완전 삭제
echo "3️⃣  기존 Pods 삭제 중..."
rm -rf Pods Podfile.lock .symlinks
echo "✅ 기존 Pods 삭제 완료"
echo ""

# 5단계: CocoaPods 설치 확인
echo "4️⃣  CocoaPods 확인 중..."
if ! command -v pod &> /dev/null; then
    echo "❌ 오류: CocoaPods이 설치되어 있지 않습니다"
    echo ""
    echo "📋 CocoaPods 설치 방법:"
    echo "   sudo gem install cocoapods"
    echo ""
    exit 1
fi

POD_VERSION=$(pod --version)
echo "✅ CocoaPods 버전: $POD_VERSION"
echo ""

# 6단계: Pod Deintegrate (선택사항)
echo "5️⃣  Pod Deintegrate 실행 중..."
if command -v pod &> /dev/null; then
    pod deintegrate || true
    echo "✅ Pod Deintegrate 완료"
else
    echo "⚠️  pod 명령어를 찾을 수 없습니다. 건너뜁니다."
fi
echo ""

# 7단계: Pod Install
echo "6️⃣  Pod Install 실행 중... (시간이 걸릴 수 있습니다)"
echo ""
pod install --repo-update

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Pod Install 성공!"
    echo ""
else
    echo ""
    echo "❌ Pod Install 실패"
    echo ""
    echo "📋 수동 해결 방법:"
    echo "   1. pod repo update"
    echo "   2. pod cache clean --all"
    echo "   3. pod install"
    echo ""
    exit 1
fi

# 8단계: audioplayers_darwin 확인
echo "7️⃣  audioplayers_darwin 설치 확인 중..."
if grep -q "audioplayers_darwin" Podfile.lock; then
    AUDIOPLAYERS_VERSION=$(grep "audioplayers_darwin" Podfile.lock | head -1 | sed 's/.*(\(.*\))/\1/')
    echo "✅ audioplayers_darwin 설치됨 (버전: $AUDIOPLAYERS_VERSION)"
else
    echo "⚠️  경고: audioplayers_darwin이 Podfile.lock에 없습니다"
    echo "   pubspec.yaml의 audioplayers 버전을 확인하세요"
fi
echo ""

# 9단계: Derived Data 정리 (선택사항)
echo "8️⃣  Xcode Derived Data 정리 중..."
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData
    echo "✅ Derived Data 정리 완료"
else
    echo "ℹ️  Derived Data 디렉토리가 없습니다"
fi
echo ""

# 완료
echo "======================================================================"
echo "✅ iOS 빌드 오류 수정 완료!"
echo "======================================================================"
echo ""
echo "📱 다음 단계:"
echo "   1. Xcode에서 Runner.xcworkspace 열기 (⚠️ .xcodeproj 아님!)"
echo "      open Runner.xcworkspace"
echo ""
echo "   2. Xcode에서 Clean Build Folder"
echo "      Product → Clean Build Folder (Shift+Cmd+K)"
echo ""
echo "   3. Xcode에서 빌드"
echo "      Product → Build (Cmd+B)"
echo ""
echo "   4. 실제 iOS 기기 또는 시뮬레이터에서 실행"
echo ""
echo "🔍 문제가 계속되면:"
echo "   - IOS_BUILD_ERROR_FIX.md 문서 참조"
echo "   - Xcode 콘솔에서 상세 오류 메시지 확인"
echo ""
