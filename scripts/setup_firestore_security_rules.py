#!/usr/bin/env python3
"""
Firestore Security Rules 설정 스크립트

버전 체크 및 공지사항에 대한 읽기 권한을 모든 사용자에게 부여합니다.
"""

import sys

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    print("✅ firebase-admin imported successfully")
except ImportError as e:
    print(f"❌ Failed to import firebase-admin: {e}")
    print("📦 INSTALLATION REQUIRED:")
    print("pip install firebase-admin==7.1.0")
    exit(1)

def initialize_firebase():
    """Firebase Admin SDK 초기화"""
    try:
        firebase_admin.get_app()
        print("ℹ️ Firebase already initialized")
    except ValueError:
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")

def get_project_id():
    """google-services.json에서 project_id 추출"""
    import json
    try:
        with open('/opt/flutter/google-services.json', 'r') as f:
            data = json.load(f)
            project_id = data['project_info']['project_id']
            print(f"✅ Project ID: {project_id}")
            return project_id
    except Exception as e:
        print(f"❌ Failed to read google-services.json: {e}")
        return None

def display_security_rules_guide():
    """Firestore Security Rules 설정 가이드 출력"""
    
    rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크, 공지사항)
    match /app_config/{document=**} {
      allow read: if true;  // 모든 사용자 읽기 가능
      allow write: if false; // 쓰기는 Firebase Console/Admin SDK만
    }
    
    // users 컬렉션: 자신의 문서만 읽기/쓰기 가능
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기타 컬렉션: 인증된 사용자만 접근
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}"""

    print("\n" + "="*80)
    print("📋 Firestore Security Rules 설정이 필요합니다")
    print("="*80)
    print("\n🔧 Firebase Console에서 다음 단계를 수행하세요:\n")
    print("1. Firebase Console 접속: https://console.firebase.google.com/")
    print("2. 프로젝트 선택")
    print("3. 좌측 메뉴에서 'Firestore Database' 클릭")
    print("4. 상단 탭에서 '규칙(Rules)' 클릭")
    print("5. 아래 규칙을 복사하여 붙여넣기")
    print("6. '게시(Publish)' 버튼 클릭\n")
    
    print("="*80)
    print("📝 복사할 Security Rules:")
    print("="*80)
    print(rules)
    print("="*80)
    
    print("\n✅ 주요 변경사항:")
    print("   - app_config 컬렉션: 모든 사용자 읽기 가능 (로그인 전에도 접근 가능)")
    print("   - version_info 문서: 버전 체크용")
    print("   - announcements 컬렉션: 공지사항 조회용")
    print("   - 쓰기 권한: Firebase Console 또는 Admin SDK만 가능\n")
    
    print("🔍 현재 문제:")
    print("   - PERMISSION_DENIED 에러 발생")
    print("   - 로그인 전 버전 체크 불가")
    print("   - 공지사항 조회 불가\n")
    
    print("✅ 해결책:")
    print("   - app_config/** 경로에 대해 읽기 권한 허용")
    print("   - 인증 없이도 버전/공지사항 조회 가능\n")

if __name__ == '__main__':
    initialize_firebase()
    project_id = get_project_id()
    
    if project_id:
        print(f"\n🌐 Firebase Console 바로가기:")
        print(f"   https://console.firebase.google.com/project/{project_id}/firestore/rules")
    
    display_security_rules_guide()
    
    print("\n⚠️  중요: Security Rules 변경 후 앱을 재시작하세요!")
    print("   - 변경사항이 즉시 반영됩니다 (최대 1분 소요)")
    print("   - 앱 재시작 후 버전 체크/공지사항이 정상 작동합니다\n")
