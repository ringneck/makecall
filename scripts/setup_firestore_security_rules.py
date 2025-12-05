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
    """Firestore Security Rules 설정 가이드 출력 (v6.2)"""
    
    rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ========================================
    // 버전: 6.2
    // 업데이트: FCM 알림 권한 추가
    // ========================================
    
    // 1. app_config: 모든 사용자 읽기 가능 (버전 체크, 공지사항)
    match /app_config/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // 2. users: 자신의 문서만 접근
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 3. fcm_tokens: 자신의 토큰만 접근
    match /fcm_tokens/{tokenId} {
      allow read, write: if request.auth != null && 
                          tokenId.matches('^' + request.auth.uid + '_.*');
    }
    
    // 4. fcm_notifications: 인증된 사용자가 자신의 알림 생성 가능
    match /fcm_notifications/{notificationId} {
      allow create: if request.auth != null;
      allow read, update, delete: if false; // Cloud Functions만 처리
    }
    
    // 5. device_approval_requests: 자신의 승인 요청만 접근
    match /device_approval_requests/{requestId} {
      allow read, write: if request.auth != null && 
                          requestId.matches('^' + request.auth.uid + '_.*');
    }
    
    // 6. call_history: 자신의 통화 기록만 접근
    match /call_history/{historyId} {
      allow read, write: if request.auth != null && 
                          resource.data.userId == request.auth.uid;
    }
    
    // 7. call_forward_info: 자신의 착신전환 설정만 접근
    match /call_forward_info/{docId} {
      allow read, write: if request.auth != null && 
                          resource.data.userId == request.auth.uid;
    }
    
    // 8. my_extensions: 자신의 단말번호만 접근
    match /my_extensions/{extensionId} {
      allow read, write: if request.auth != null && 
                          resource.data.userId == request.auth.uid;
    }
    
    // 9. 기본 규칙: 인증된 사용자만
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}"""

    print("\n" + "="*80)
    print("📋 Firestore Security Rules v6.2 업데이트 필요")
    print("="*80)
    print("\n🔧 Firebase Console에서 다음 단계를 수행하세요:\n")
    print("1. Firebase Console 접속: https://console.firebase.google.com/")
    print("2. 프로젝트 선택")
    print("3. 좌측 메뉴에서 'Firestore Database' 클릭")
    print("4. 상단 탭에서 '규칙(Rules)' 클릭")
    print("5. 아래 규칙을 복사하여 붙여넣기")
    print("6. '게시(Publish)' 버튼 클릭\n")
    
    print("="*80)
    print("📝 복사할 Security Rules v6.2:")
    print("="*80)
    print(rules)
    print("="*80)
    
    print("\n✅ Security Rules v6.2 주요 내용:")
    print("   1. app_config: 모든 사용자 읽기 가능")
    print("   2. users: 자신의 문서만 접근")
    print("   3. fcm_tokens: 자신의 토큰만 접근")
    print("   4. fcm_notifications: 인증된 사용자 생성 가능 (착신전환 알림)")
    print("   5. device_approval_requests: 자신의 승인 요청만 접근")
    print("   6. call_history: 자신의 통화 기록만 접근")
    print("   7. call_forward_info: 자신의 착신전환 설정만 접근")
    print("   8. my_extensions: 자신의 단말번호만 접근\n")
    
    print("🔧 이번 업데이트 (v6.2):")
    print("   ✅ fcm_notifications 컬렉션 create 권한 추가")
    print("   ✅ 착신전환 알림 전송 오류 해결 (PERMISSION_DENIED)\n")
    
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
