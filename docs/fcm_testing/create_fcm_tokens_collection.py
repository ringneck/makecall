#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FCM 토큰 저장을 위한 Firestore 컬렉션 생성 스크립트
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

def main():
    try:
        # Firebase Admin SDK 초기화
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        print("✅ Firebase Admin SDK 초기화 완료")
        
        # fcm_tokens 컬렉션 생성 (샘플 데이터)
        print("\n📱 fcm_tokens 컬렉션 생성 중...")
        
        # 컬렉션 구조 설명
        sample_token = {
            'userId': 'sample_user_id',
            'token': 'sample_fcm_token_string',
            'deviceId': 'sample_device_id',
            'deviceName': 'Samsung Galaxy S21',
            'platform': 'android',  # 'android' or 'ios' or 'web'
            'appVersion': '1.0.0',
            'isActive': True,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
            'lastUsedAt': firestore.SERVER_TIMESTAMP,
        }
        
        # 샘플 문서 추가 (문서 ID는 FCM 토큰을 사용)
        doc_ref = db.collection('fcm_tokens').document('sample_fcm_token')
        doc_ref.set(sample_token)
        print("✅ 샘플 fcm_tokens 문서 생성 완료")
        
        # user_notification_settings 컬렉션 생성
        print("\n🔔 user_notification_settings 컬렉션 생성 중...")
        
        sample_settings = {
            'userId': 'sample_user_id',
            'pushEnabled': True,
            'soundEnabled': True,
            'vibrationEnabled': True,
            'incomingCallNotification': True,
            'missedCallNotification': True,
            'messageNotification': True,
            'quietHoursEnabled': False,
            'quietHoursStart': '22:00',
            'quietHoursEnd': '08:00',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        
        doc_ref = db.collection('user_notification_settings').document('sample_user_id')
        doc_ref.set(sample_settings)
        print("✅ 샘플 user_notification_settings 문서 생성 완료")
        
        # notification_logs 컬렉션 생성 (알림 발송 이력)
        print("\n📋 notification_logs 컬렉션 생성 중...")
        
        sample_log = {
            'userId': 'sample_user_id',
            'fcmToken': 'sample_fcm_token',
            'title': '수신 전화',
            'body': '010-1234-5678에서 전화가 왔습니다',
            'data': {
                'type': 'incoming_call',
                'phoneNumber': '010-1234-5678',
                'callId': 'call_12345',
            },
            'status': 'sent',  # 'sent', 'delivered', 'failed'
            'sentAt': firestore.SERVER_TIMESTAMP,
            'deliveredAt': None,
            'errorMessage': None,
        }
        
        doc_ref = db.collection('notification_logs').add(sample_log)
        print("✅ 샘플 notification_logs 문서 생성 완료")
        
        print("\n" + "="*60)
        print("🎉 FCM 관련 Firestore 컬렉션 생성 완료!")
        print("="*60)
        print("\n📊 생성된 컬렉션:")
        print("1. fcm_tokens - FCM 토큰 저장")
        print("   - userId: 사용자 ID")
        print("   - token: FCM 토큰 문자열")
        print("   - deviceId: 기기 고유 ID")
        print("   - platform: android/ios/web")
        print("   - isActive: 토큰 활성화 상태")
        print("")
        print("2. user_notification_settings - 사용자별 알림 설정")
        print("   - pushEnabled: 푸시 알림 활성화")
        print("   - soundEnabled: 알림음 활성화")
        print("   - vibrationEnabled: 진동 활성화")
        print("   - incomingCallNotification: 수신 전화 알림")
        print("   - missedCallNotification: 부재중 전화 알림")
        print("")
        print("3. notification_logs - 알림 발송 이력")
        print("   - title, body: 알림 제목/내용")
        print("   - status: 발송 상태")
        print("   - sentAt: 발송 시간")
        print("")
        print("⚠️  샘플 데이터는 테스트 후 삭제하세요!")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
