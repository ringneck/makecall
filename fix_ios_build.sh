#!/bin/bash

# iOS 빌드 오류 자동 수정 스크립트
# "Command PhaseScriptExecution failed with a nonzero exit code" 해결

echo "🔧 iOS 빌드 오류 자동 수정 시작..."
echo ""

# 현재 디렉토리 확인
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 오류: Flutter 프로젝트 루트 디렉토리에서 실행하세요."
    exit 1
fi

# 1단계: Flutter Clean
echo "1️⃣ Flutter 프로젝트 정리 중..."
flutter clean
echo "✅ Flutter clean 완료"
echo ""

# 2단계: iOS 빌드 캐시 삭제
echo "2️⃣ iOS 빌드 캐시 삭제 중..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec
rm -rf ios/Runner.xcworkspace
echo "✅ iOS 캐시 삭제 완료"
echo ""

# 3단계: Xcode 파생 데이터 삭제
echo "3️⃣ Xcode 파생 데이터 삭제 중..."
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    echo "✅ Xcode 파생 데이터 삭제 완료"
else
    echo "⚠️  Xcode 파생 데이터 폴더 없음 (스킵)"
fi
echo ""

# 4단계: Flutter 의존성 재설치
echo "4️⃣ Flutter 의존성 재설치 중..."
flutter pub get
echo "✅ Flutter pub get 완료"
echo ""

# 5단계: CocoaPods 설치 확인
echo "5️⃣ CocoaPods 설치 확인 중..."
if ! command -v pod &> /dev/null; then
    echo "⚠️  CocoaPods가 설치되어 있지 않습니다."
    echo "📝 다음 명령어로 설치하세요:"
    echo "   sudo gem install cocoapods"
    echo ""
    echo "💡 Apple Silicon Mac을 사용 중이라면:"
    echo "   arch -x86_64 sudo gem install cocoapods"
    exit 1
fi
echo "✅ CocoaPods 설치됨: $(pod --version)"
echo ""

# 6단계: CocoaPods 캐시 정리
echo "6️⃣ CocoaPods 캐시 정리 중..."
pod cache clean --all 2>/dev/null || echo "⚠️  CocoaPods 캐시 정리 실패 (무시)"
echo "✅ CocoaPods 캐시 정리 완료"
echo ""

# 7단계: Pod 재설치
echo "7️⃣ CocoaPods 의존성 재설치 중..."
cd ios

# Apple Silicon Mac 감지
if [[ $(uname -m) == 'arm64' ]]; then
    echo "🍎 Apple Silicon Mac 감지 - Rosetta 사용"
    arch -x86_64 pod install
else
    pod install
fi

cd ..
echo "✅ Pod install 완료"
echo ""

# 8단계: 빌드 스크립트 권한 확인
echo "8️⃣ 빌드 스크립트 권한 확인 중..."
if [ -f "ios/Flutter/flutter_export_environment.sh" ]; then
    chmod +x ios/Flutter/flutter_export_environment.sh
    echo "✅ flutter_export_environment.sh 권한 설정"
fi

if [ -f "ios/Flutter/podhelper.rb" ]; then
    chmod +x ios/Flutter/podhelper.rb
    echo "✅ podhelper.rb 권한 설정"
fi
echo ""

# 완료
echo "=========================================="
echo "✅ iOS 빌드 환경 수정 완료!"
echo "=========================================="
echo ""
echo "📱 다음 단계:"
echo "1. Xcode에서 프로젝트 열기:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. Xcode에서 Clean Build Folder:"
echo "   Product → Clean Build Folder (Shift + Command + K)"
echo ""
echo "3. 빌드 시작:"
echo "   Product → Run (Command + R)"
echo ""
echo "💡 추가 도움이 필요하면 IOS_BUILD_FIX_GUIDE.md 파일을 참고하세요."
