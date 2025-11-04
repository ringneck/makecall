#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FCM Access Token 획득 스크립트

사용법:
    python3 get_access_token.py
    
출력:
    - Access Token (Bearer 토큰)
    - Project ID
    - Token 만료 시간
"""

import firebase_admin
from firebase_admin import credentials
import google.auth.transport.requests
import json
from datetime import datetime

def get_access_token():
    """Firebase Admin SDK를 사용하여 Access Token 획득"""
    try:
        # Admin SDK 초기화
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        
        # 이미 초기화되어 있는지 확인
        try:
            firebase_admin.initialize_app(cred)
        except ValueError:
            # 이미 초기화된 경우 무시
            pass
        
        # Access Token 생성
        access_token_info = cred.get_access_token()
        access_token = access_token_info.access_token if hasattr(access_token_info, 'access_token') else access_token_info
        
        # Project ID 추출
        with open('/opt/flutter/firebase-admin-sdk.json') as f:
            admin_sdk_data = json.load(f)
            project_id = admin_sdk_data['project_id']
        
        # 결과 출력
        print("=" * 70)
        print("🔑 FCM Access Token 정보")
        print("=" * 70)
        print()
        print("📋 Project ID:")
        print(f"   {project_id}")
        print()
        print("🔐 Access Token (Bearer):")
        print(f"   {access_token}")
        print()
        print("⏰ Token 만료 시간:")
        expiry = getattr(cred, 'expiry', None)
        if expiry:
            expiry_str = expiry.strftime('%Y-%m-%d %H:%M:%S')
            print(f"   {expiry_str}")
            
            # 남은 시간 계산
            remaining = expiry - datetime.now(expiry.tzinfo)
            minutes = int(remaining.total_seconds() / 60)
            print(f"   (약 {minutes}분 후 만료)")
        else:
            print("   약 1시간 (자동 갱신됨)")
        print()
        print("=" * 70)
        print("💡 사용 방법")
        print("=" * 70)
        print()
        print("1. curl 사용:")
        print(f'   curl -X POST \\')
        print(f'     "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send" \\')
        print(f'     -H "Authorization: Bearer {access_token[:50]}..." \\')
        print(f'     -H "Content-Type: application/json" \\')
        print(f'     -d \'{{...}}\'')
        print()
        print("2. Postman/Insomnia:")
        print(f'   URL: https://fcm.googleapis.com/v1/projects/{project_id}/messages:send')
        print(f'   Header: Authorization: Bearer {access_token[:50]}...')
        print()
        print("3. 환경 변수로 저장:")
        print(f'   export FCM_ACCESS_TOKEN="{access_token}"')
        print(f'   export FCM_PROJECT_ID="{project_id}"')
        print()
        print("=" * 70)
        
        return {
            'access_token': access_token,
            'project_id': project_id,
            'expiry': getattr(cred, 'expiry', None),
        }
        
    except FileNotFoundError:
        print("❌ Firebase Admin SDK JSON 파일을 찾을 수 없습니다:")
        print("   /opt/flutter/firebase-admin-sdk.json")
        print()
        print("💡 Firebase Console에서 다운로드:")
        print("   1. Project Settings → Service accounts")
        print("   2. 'Generate new private key' 클릭")
        print("   3. JSON 파일을 /opt/flutter/ 디렉토리에 저장")
        return None
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    result = get_access_token()
    
    if result:
        print("✅ Access Token 획득 성공!")
        print()
        print("📌 이 토큰을 복사하여 FCM API 호출에 사용하세요.")
    else:
        print("❌ Access Token 획득 실패")
        exit(1)

if __name__ == '__main__':
    main()
