#!/usr/bin/env python3
"""
Firestore 보안 규칙 업데이트 - call_history 컬렉션 권한 추가
로그아웃 상태에서도 통화 확인(status update)이 가능하도록 설정
"""

import firebase_admin
from firebase_admin import credentials, firestore
import sys

def update_firestore_rules():
    """Firestore 보안 규칙 업데이트 - call_history 접근 권한 추가"""
    
    try:
        # Firebase Admin SDK 초기화
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        
        # 이미 초기화되어 있는지 확인
        try:
            firebase_admin.get_app()
            print("✅ Firebase Admin SDK already initialized")
        except ValueError:
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized")
        
        # Firestore 클라이언트 생성
        db = firestore.client()
        
        # 프로젝트 ID 추출
        project_id = cred.project_id
        print(f"📋 Project ID: {project_id}")
        
        # Firestore 보안 규칙
        security_rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 🔓 app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크용)
    match /app_config/{document=**} {
      allow read: if true;  // 누구나 읽기 가능
      allow write: if false; // 쓰기는 불가 (관리자만 콘솔에서 수정)
    }
    
    // 📞 call_history 컬렉션: 읽기 및 status 업데이트 허용 (로그아웃 상태 포함)
    match /call_history/{callId} {
      allow read: if true;  // 누구나 읽기 가능 (통화 기록 확인용)
      allow create: if request.auth != null;  // 생성은 인증된 사용자만
      allow update: if true;  // 업데이트는 누구나 가능 (통화 확인용)
      allow delete: if request.auth != null;  // 삭제는 인증된 사용자만
    }
    
    // 🔐 기본 규칙: 인증된 사용자만 접근 가능
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}"""
        
        print("\n📝 업데이트할 Firestore 보안 규칙:")
        print("=" * 70)
        print(security_rules)
        print("=" * 70)
        
        print("\n⚠️  Firestore 보안 규칙은 Firebase Console에서 수동으로 설정해야 합니다.")
        print("\n🔧 수동 설정 방법:")
        print("1. Firebase Console 접속: https://console.firebase.google.com/")
        print(f"2. 프로젝트 선택: {project_id}")
        print("3. 좌측 메뉴: Firestore Database → 규칙(Rules) 탭")
        print("4. 위의 보안 규칙을 복사하여 붙여넣기")
        print("5. '게시(Publish)' 버튼 클릭")
        
        print("\n✅ 규칙이 적용되면:")
        print("   - app_config 읽기 가능 (모든 사용자)")
        print("   - call_history 읽기 가능 (모든 사용자)")
        print("   - call_history status 업데이트 가능 (로그아웃 상태 포함)")
        print("   - 기타 컬렉션은 인증된 사용자만 접근")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🔥 Firestore 보안 규칙 업데이트 (call_history 추가)...\n")
    success = update_firestore_rules()
    sys.exit(0 if success else 1)
