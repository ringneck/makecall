#!/bin/bash

# 카카오 Key Hash 추출 스크립트
# Android Debug Keystore용

echo "=========================================="
echo "📱 Kakao Android Key Hash Generator"
echo "=========================================="
echo ""

# Debug keystore 경로
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ ! -f "$DEBUG_KEYSTORE" ]; then
    echo "❌ Debug keystore를 찾을 수 없습니다: $DEBUG_KEYSTORE"
    echo ""
    echo "💡 Flutter 프로젝트를 한 번이라도 실행하면 자동으로 생성됩니다:"
    echo "   flutter run"
    exit 1
fi

echo "🔑 Debug Keystore에서 Key Hash 추출 중..."
echo "   경로: $DEBUG_KEYSTORE"
echo ""

# Key Hash 생성
KEY_HASH=$(keytool -exportcert -alias androiddebugkey -keystore "$DEBUG_KEYSTORE" \
    -storepass android -keypass android 2>/dev/null | \
    openssl sha1 -binary | openssl base64)

if [ -z "$KEY_HASH" ]; then
    echo "❌ Key Hash 추출 실패"
    echo ""
    echo "💡 필요한 도구가 설치되어 있는지 확인하세요:"
    echo "   - keytool (Java JDK 포함)"
    echo "   - openssl"
    exit 1
fi

echo "=========================================="
echo "✅ Key Hash 추출 완료!"
echo "=========================================="
echo ""
echo "Key Hash: $KEY_HASH"
echo ""
echo "=========================================="
echo "🔗 카카오 개발자 콘솔 등록 방법:"
echo "=========================================="
echo "1. https://developers.kakao.com 접속"
echo "2. 내 애플리케이션 선택"
echo "3. 앱 설정 > 플랫폼 > Android"
echo "4. 키 해시에 다음 값을 등록:"
echo ""
echo "   $KEY_HASH"
echo ""
echo "=========================================="
echo ""
echo "📋 Release Keystore Key Hash도 필요하신가요?"
echo "   다음 명령어를 사용하세요:"
echo ""
echo "   keytool -exportcert -alias YOUR_ALIAS \\"
echo "     -keystore YOUR_KEYSTORE_PATH \\"
echo "     -storepass YOUR_STORE_PASSWORD \\"
echo "     -keypass YOUR_KEY_PASSWORD | \\"
echo "     openssl sha1 -binary | openssl base64"
echo ""
