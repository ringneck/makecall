#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FCM 테스트 메시지 발송 스크립트
"""

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from datetime import datetime
import sys

def get_active_fcm_tokens(db, limit=5):
    """활성 FCM 토큰 조회"""
    try:
        tokens_ref = db.collection('fcm_tokens')
        query = tokens_ref.where('isActive', '==', True).limit(limit)
        docs = query.stream()
        
        tokens = []
        for doc in docs:
            data = doc.data()
            tokens.append({
                'token': doc.id,
                'userId': data.get('userId'),
                'deviceName': data.get('deviceName'),
                'platform': data.get('platform'),
            })
        
        return tokens
    except Exception as e:
        print(f"❌ 토큰 조회 오류: {e}")
        return []

def send_test_notification(token, message_type='basic'):
    """테스트 알림 발송"""
    try:
        # 메시지 템플릿
        messages = {
            'basic': {
                'title': '🔔 테스트 알림',
                'body': 'FCM 푸시 알림 테스트입니다',
                'data': {
                    'type': 'test',
                    'timestamp': str(datetime.now().timestamp()),
                }
            },
            'incoming_call': {
                'title': '김철수',
                'body': '010-1234-5678',
                'data': {
                    'type': 'incoming_call',
                    'caller_name': '김철수',
                    'caller_number': '010-1234-5678',
                    'caller_avatar': '',  # 옵션: 아바타 이미지 URL
                    'callId': f'call_{datetime.now().timestamp()}',
                }
            },
            'missed_call': {
                'title': '📵 부재중 전화',
                'body': '010-9876-5432님의 부재중 전화 1건',
                'data': {
                    'type': 'missed_call',
                    'phoneNumber': '010-9876-5432',
                    'missedAt': str(datetime.now().timestamp()),
                }
            },
            'message': {
                'title': '💬 새 메시지',
                'body': '홍길동: 안녕하세요!',
                'data': {
                    'type': 'message',
                    'sender': '홍길동',
                    'messageId': f'msg_{datetime.now().timestamp()}',
                }
            }
        }
        
        template = messages.get(message_type, messages['basic'])
        
        # FCM 메시지 생성
        message = messaging.Message(
            notification=messaging.Notification(
                title=template['title'],
                body=template['body'],
            ),
            data=template['data'],
            token=token,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    channel_id='default',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound='default',
                    ),
                ),
            ),
        )
        
        # 메시지 발송
        response = messaging.send(message)
        print(f"✅ 메시지 발송 성공: {response}")
        return True
        
    except Exception as e:
        print(f"❌ 메시지 발송 실패: {e}")
        return False

def log_notification(db, token, title, body, data, status):
    """알림 로그 저장"""
    try:
        db.collection('notification_logs').add({
            'fcmToken': token,
            'title': title,
            'body': body,
            'data': data,
            'status': status,
            'sentAt': firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        print(f"⚠️  로그 저장 실패: {e}")

def main():
    try:
        # Firebase Admin SDK 초기화
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        
        print("="*60)
        print("🔔 FCM 테스트 메시지 발송")
        print("="*60)
        
        # 활성 FCM 토큰 조회
        print("\n📱 활성 FCM 토큰 조회 중...")
        tokens = get_active_fcm_tokens(db)
        
        if not tokens:
            print("❌ 활성 FCM 토큰이 없습니다.")
            print("💡 앱을 실행하고 로그인하여 FCM 토큰을 생성하세요.")
            return
        
        print(f"✅ {len(tokens)}개의 활성 토큰 발견\n")
        
        # 토큰 목록 표시
        for i, token_info in enumerate(tokens, 1):
            print(f"{i}. 사용자: {token_info['userId']}")
            print(f"   기기: {token_info['deviceName']} ({token_info['platform']})")
            print(f"   토큰: {token_info['token'][:20]}...")
            print()
        
        # 메시지 타입 선택
        print("메시지 타입을 선택하세요:")
        print("1. 기본 테스트 알림")
        print("2. 수신 전화 알림")
        print("3. 부재중 전화 알림")
        print("4. 새 메시지 알림")
        print("5. 모든 타입 순차 발송")
        print()
        
        choice = input("선택 (1-5, Enter=1): ").strip() or '1'
        
        message_types = {
            '1': 'basic',
            '2': 'incoming_call',
            '3': 'missed_call',
            '4': 'message',
        }
        
        # 대상 토큰 선택
        if len(tokens) == 1:
            target_token = tokens[0]['token']
            print(f"\n📤 {tokens[0]['deviceName']}로 메시지 발송 중...")
        else:
            token_choice = input(f"\n토큰 선택 (1-{len(tokens)}, Enter=1): ").strip() or '1'
            try:
                token_idx = int(token_choice) - 1
                if 0 <= token_idx < len(tokens):
                    target_token = tokens[token_idx]['token']
                    print(f"\n📤 {tokens[token_idx]['deviceName']}로 메시지 발송 중...")
                else:
                    target_token = tokens[0]['token']
                    print(f"\n📤 {tokens[0]['deviceName']}로 메시지 발송 중...")
            except ValueError:
                target_token = tokens[0]['token']
                print(f"\n📤 {tokens[0]['deviceName']}로 메시지 발송 중...")
        
        print()
        
        # 메시지 발송
        if choice == '5':
            # 모든 타입 순차 발송
            for msg_type in message_types.values():
                print(f"📨 {msg_type} 메시지 발송 중...")
                success = send_test_notification(target_token, msg_type)
                if success:
                    print(f"✅ {msg_type} 발송 완료\n")
                else:
                    print(f"❌ {msg_type} 발송 실패\n")
        else:
            # 선택한 타입 발송
            msg_type = message_types.get(choice, 'basic')
            success = send_test_notification(target_token, msg_type)
        
        print("\n" + "="*60)
        print("🎉 테스트 완료!")
        print("="*60)
        print("\n💡 팁:")
        print("- 기기에서 알림을 확인하세요")
        print("- Firestore의 notification_logs 컬렉션에서 로그를 확인할 수 있습니다")
        print("- 앱의 알림 설정이 활성화되어 있는지 확인하세요")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
