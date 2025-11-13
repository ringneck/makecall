#!/usr/bin/env python3
"""Firestore 데이터 상태 확인 스크립트"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys
import os
from pathlib import Path

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
    
    # 기존 앱이 있으면 삭제
    try:
        firebase_admin.get_app()
        firebase_admin.delete_app(firebase_admin.get_app())
    except ValueError:
        pass
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    print("=" * 60)
    print("📊 MAKECALL Firestore 데이터 상태")
    print("=" * 60)
    
    # 1. FCM 토큰 확인
    print("\n1️⃣ FCM 토큰 (norman@olssoo.com):")
    tokens = db.collection('fcm_tokens').where('userId', '==', '00UZFjXMjnSj0ThUnGlgkn8cgVy2').stream()
    token_count = 0
    for token in tokens:
        token_count += 1
        data = token.to_dict()
        print(f"   {token_count}. {data.get('deviceName', 'N/A')} ({data.get('platform', 'N/A')})")
        print(f"      - 활성: {data.get('isActive', False)}")
        print(f"      - 토큰: {data.get('fcmToken', 'N/A')[:30]}...")
        print(f"      - 기기 ID: {data.get('deviceId', 'N/A')}")
    
    if token_count == 0:
        print("   ❌ 활성 토큰 없음")
    
    # 2. 승인 요청 확인
    print("\n2️⃣ 기기 승인 요청 (norman@olssoo.com):")
    approvals = db.collection('device_approval_requests').stream()
    approval_count = 0
    for approval in approvals:
        doc_data = approval.to_dict()
        if doc_data.get('userId') == '00UZFjXMjnSj0ThUnGlgkn8cgVy2':
            approval_count += 1
            print(f"   {approval_count}. {approval.id}")
            print(f"      - 상태: {doc_data.get('status', 'N/A')}")
            print(f"      - 새 기기: {doc_data.get('newDeviceName', 'N/A')} ({doc_data.get('newPlatform', 'N/A')})")
            print(f"      - 생성 시간: {doc_data.get('createdAt', 'N/A')}")
    
    if approval_count == 0:
        print("   ❌ 승인 요청 없음")
    
    # 3. 알림 큐 확인
    print("\n3️⃣ 알림 큐:")
    notifications = db.collection('notification_queue').stream()
    notif_count = 0
    for notif in notifications:
        notif_count += 1
        data = notif.to_dict()
        print(f"   {notif_count}. {notif.id}")
        print(f"      - 유형: {data.get('type', 'N/A')}")
        print(f"      - 수신자: {data.get('recipientToken', 'N/A')[:30]}...")
        print(f"      - 생성 시간: {data.get('createdAt', 'N/A')}")
    
    if notif_count == 0:
        print("   ✅ 알림 큐 비어있음 (정상)")
    
    print("\n" + "=" * 60)
    
except Exception as e:
    print(f"❌ 오류 발생: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

