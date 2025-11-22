#!/usr/bin/env python3
"""이전 테스트 데이터 정리 스크립트"""

import warnings
import sys
import os
from pathlib import Path

# Suppress Python version and SSL warnings
warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', message='urllib3 v2 only supports OpenSSL')

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError as e:
    print(f"❌ Firebase Admin SDK import 실패: {e}")
    print("\n📦 Firebase Admin SDK 설치 필요:")
    print("   pip3 install --upgrade firebase-admin")
    print("\n💡 Python 버전 업그레이드 권장:")
    print("   현재 Python 3.9.6은 EOL(End of Life) 버전입니다.")
    print("   Python 3.10 이상으로 업그레이드를 권장합니다.")
    sys.exit(1)

try:
    # Firebase Admin SDK 파일 경로 찾기
    possible_paths = [
        '/opt/flutter/firebase-admin-sdk.json',  # 서버 환경
        'firebase-admin-sdk.json',  # 현재 디렉토리
        '../firebase-admin-sdk.json',  # 상위 디렉토리
        Path.home() / 'makecall' / 'firebase-admin-sdk.json',  # 홈 디렉토리
    ]
    
    sdk_path = None
    for path in possible_paths:
        if os.path.exists(path):
            sdk_path = str(path)
            break
    
    if sdk_path is None:
        print("❌ Firebase Admin SDK 파일을 찾을 수 없습니다.")
        print("\n📝 다음 위치 중 하나에 firebase-admin-sdk.json 파일을 배치해주세요:")
        print("   1. 현재 디렉토리")
        print("   2. 프로젝트 루트 디렉토리")
        print("   3. ~/makecall/ 디렉토리")
        print("\n💡 Firebase Console에서 다운로드:")
        print("   Project Settings → Service accounts → Generate new private key")
        sys.exit(1)
    
    print(f"✅ Firebase Admin SDK 파일 발견: {sdk_path}\n")
    
    # Firebase Admin SDK 초기화
    cred = credentials.Certificate(sdk_path)
    
    try:
        firebase_admin.get_app()
        firebase_admin.delete_app(firebase_admin.get_app())
    except ValueError:
        pass
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print("=" * 60)
    print("🧹 테스트 데이터 정리 시작")
    print("=" * 60)
    
    # 1. Norman의 FCM 토큰 모두 비활성화
    print("\n1️⃣ FCM 토큰 비활성화 중...")
    tokens = db.collection('fcm_tokens').where('userId', '==', '00UZFjXMjnSj0ThUnGlgkn8cgVy2').stream()
    token_count = 0
    for token in tokens:
        token.reference.update({'isActive': False})
        token_count += 1
    print(f"   ✅ {token_count}개 토큰 비활성화 완료")
    
    # 2. Norman의 승인 요청 삭제
    print("\n2️⃣ 승인 요청 삭제 중...")
    approvals = db.collection('device_approval_requests').stream()
    approval_count = 0
    for approval in approvals:
        if approval.to_dict().get('userId') == '00UZFjXMjnSj0ThUnGlgkn8cgVy2':
            approval.reference.delete()
            approval_count += 1
    print(f"   ✅ {approval_count}개 승인 요청 삭제 완료")
    
    # 3. 알림 큐 정리
    print("\n3️⃣ 알림 큐 정리 중...")
    notifications = db.collection('notification_queue').stream()
    notif_count = 0
    for notif in notifications:
        notif.reference.delete()
        notif_count += 1
    print(f"   ✅ {notif_count}개 알림 삭제 완료")
    
    print("\n" + "=" * 60)
    print("✅ 정리 완료! 이제 처음부터 테스트할 수 있습니다.")
    print("=" * 60)
    
except Exception as e:
    print(f"❌ 오류 발생: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

