#!/usr/bin/env python3
"""
Firestore 보안 규칙 자동 적용 스크립트
Firebase Admin SDK를 사용하여 프로그래밍 방식으로 보안 규칙 업데이트
"""

import json
import sys
import subprocess
from google.oauth2 import service_account
from google.auth.transport.requests import Request

def apply_firestore_rules():
    """Firestore 보안 규칙을 프로그래밍 방식으로 적용"""
    
    try:
        # Firebase Admin SDK 인증 정보 로드
        cred_path = '/opt/flutter/firebase-admin-sdk.json'
        
        with open(cred_path, 'r') as f:
            cred_data = json.load(f)
        
        project_id = cred_data['project_id']
        print(f"📋 Project ID: {project_id}")
        
        # 보안 규칙 정의
        firestore_rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 🔓 app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크용)
    match /app_config/{document=**} {
      allow read: if true;  // 누구나 읽기 가능
      allow write: if false; // 쓰기는 불가 (관리자만 콘솔에서 수정)
    }
    
    // 📞 call_history 컬렉션: 읽기 및 status 업데이트 허용 (재로그인 대응)
    match /call_history/{callId} {
      allow read: if true;  // 누구나 읽기 가능 (통화 기록 확인용)
      allow create: if request.auth != null;  // 생성은 인증된 사용자만
      allow update: if true;  // 업데이트는 누구나 가능 (통화 확인용)
      allow delete: if request.auth != null;  // 삭제는 인증된 사용자만
    }
    
    // 📱 my_extensions 컬렉션: 읽기 허용 (재로그인 대응)
    match /my_extensions/{extId} {
      allow read: if true;  // 누구나 읽기 가능 (재로그인 시 StreamBuilder 접근 허용)
      allow write: if request.auth != null;  // 쓰기는 인증된 사용자만
    }
    
    // 👤 contacts 컬렉션: 읽기 허용 (재로그인 대응)
    match /contacts/{contactId} {
      allow read: if true;  // 누구나 읽기 가능 (재로그인 시 StreamBuilder 접근 허용)
      allow write: if request.auth != null;  // 쓰기는 인증된 사용자만
    }
    
    // 📇 phonebook_contacts 컬렉션: 읽기 허용 (재로그인 대응)
    match /phonebook_contacts/{pbId} {
      allow read: if true;  // 누구나 읽기 가능 (재로그인 시 StreamBuilder 접근 허용)
      allow write: if request.auth != null;  // 쓰기는 인증된 사용자만
    }
    
    // 🔐 기본 규칙: 인증된 사용자만 접근 가능
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}"""
        
        print("\n📝 적용할 Firestore 보안 규칙:")
        print("=" * 70)
        print(firestore_rules)
        print("=" * 70)
        
        # Google Cloud 인증 정보 생성
        credentials = service_account.Credentials.from_service_account_file(
            cred_path,
            scopes=['https://www.googleapis.com/auth/cloud-platform']
        )
        
        # 액세스 토큰 가져오기
        credentials.refresh(Request())
        access_token = credentials.token
        
        print("\n🔐 인증 완료, 보안 규칙 적용 중...")
        
        # Firebase REST API를 사용하여 규칙 업데이트
        url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/rulesets"
        
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
        }
        
        # Ruleset 생성
        ruleset_data = {
            'source': {
                'files': [
                    {
                        'name': 'firestore.rules',
                        'content': firestore_rules
                    }
                ]
            }
        }
        
        response = requests.post(url, headers=headers, json=ruleset_data)
        
        if response.status_code == 200:
            ruleset = response.json()
            ruleset_name = ruleset['name']
            print(f"✅ Ruleset 생성 완료: {ruleset_name}")
            
            # Ruleset을 Firestore에 적용 (릴리즈)
            # Firebase Rules API v1: PATCH는 rulesetName만 포함
            release_url = f"https://firebaserules.googleapis.com/v1/projects/{project_id}/releases/cloud.firestore"
            
            # Release 업데이트: rulesetName만 전송
            release_payload = {
                'rulesetName': ruleset_name  # camelCase 사용, name 필드 제거
            }
            
            release_response = requests.patch(
                release_url,
                headers=headers,
                json=release_payload
            )
            
            if release_response.status_code == 200:
                print("✅ Firestore 보안 규칙 적용 완료!")
                print("\n📊 적용된 규칙:")
                print(f"   - app_config: 모든 사용자 읽기 가능")
                print(f"   - call_history: 읽기 및 업데이트 가능 (재로그인 대응)")
                print(f"   - my_extensions: 읽기 가능 (재로그인 대응)")
                print(f"   - contacts: 읽기 가능 (재로그인 대응)")
                print(f"   - phonebook_contacts: 읽기 가능 (재로그인 대응)")
                print(f"   - 기타 컬렉션: 인증된 사용자만 접근")
                return True
            else:
                print(f"❌ Ruleset 릴리즈 실패: {release_response.status_code}")
                print(f"   응답: {release_response.text}")
                return False
        else:
            print(f"❌ Ruleset 생성 실패: {response.status_code}")
            print(f"   응답: {response.text}")
            print("\n💡 수동 적용 필요:")
            print("   Firebase Console → Firestore Database → 규칙(Rules)")
            print("   위의 규칙을 복사하여 붙여넣고 게시(Publish)")
            return False
        
    except FileNotFoundError:
        print("❌ Firebase Admin SDK 키 파일을 찾을 수 없습니다.")
        print("   경로: /opt/flutter/firebase-admin-sdk.json")
        return False
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        print("\n💡 수동 적용 방법:")
        print("1. Firebase Console: https://console.firebase.google.com/")
        print("2. 프로젝트 선택: makecallio")
        print("3. Firestore Database → 규칙(Rules) 탭")
        print("4. 위의 규칙을 복사하여 붙여넣기")
        print("5. 게시(Publish) 클릭")
        return False

if __name__ == "__main__":
    print("🔥 Firestore 보안 규칙 자동 적용 시작...\n")
    success = apply_firestore_rules()
    
    if success:
        print("\n🎉 완료! 규칙이 성공적으로 적용되었습니다.")
    else:
        print("\n⚠️  자동 적용 실패. 수동으로 적용해주세요.")
    
    sys.exit(0 if success else 1)
