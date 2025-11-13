#!/usr/bin/env python3
"""이전 테스트 데이터 정리 스크립트"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys

try:
    # Firebase Admin SDK 초기화
    cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
    
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

