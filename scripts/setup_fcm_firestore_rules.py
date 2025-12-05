#!/usr/bin/env python3
"""
Firestore Security Rules 업데이트 스크립트 (FCM 토큰 포함)

FCM 토큰 관리를 위한 권한 규칙을 추가합니다.
"""

import sys
import json

def get_project_id():
    """google-services.json에서 project_id 추출"""
    try:
        with open('/opt/flutter/google-services.json', 'r') as f:
            data = json.load(f)
            project_id = data['project_info']['project_id']
            print(f"✅ Project ID: {project_id}")
            return project_id
    except Exception as e:
        print(f"❌ Failed to read google-services.json: {e}")
        return None

def display_updated_security_rules():
    """업데이트된 Firestore Security Rules 출력"""
    
    rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ✅ app_config 컬렉션: 모든 사용자가 읽기 가능 (버전 체크, 공지사항)
    match /app_config/{document=**} {
      allow read: if true;  // 모든 사용자 읽기 가능
      allow write: if false; // 쓰기는 Firebase Console/Admin SDK만
    }
    
    // ✅ fcm_tokens 컬렉션: 인증된 사용자가 자신의 토큰 관리
    match /fcm_tokens/{tokenId} {
      // tokenId 형식: {userId}_{deviceId}_{platform}
      // 예: 00UZFjXMjnSj0ThUnGlgkn8cgVy2_QP1A.190711.020_Android
      
      // 읽기: 자신의 토큰만 조회 가능
      allow read: if request.auth != null && 
                     tokenId.matches('^' + request.auth.uid + '_.*');
      
      // 쓰기: 자신의 토큰만 생성/수정/삭제 가능
      allow write: if request.auth != null && 
                      tokenId.matches('^' + request.auth.uid + '_.*');
    }
    
    // ✅ approval_requests 컬렉션: 기기 승인 요청 관리
    match /approval_requests/{requestId} {
      // 읽기: 자신의 승인 요청만 조회
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // 쓰기: 자신의 승인 요청만 생성/수정
      allow write: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid;
    }
    
    // ✅ users 컬렉션: 자신의 문서만 읽기/쓰기 가능
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ✅ 기타 컬렉션: 인증된 사용자만 접근 (자신의 데이터만)
    match /{collection}/{document} {
      allow read, write: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
    }
  }
}"""

    print("\n" + "="*80)
    print("📋 Firestore Security Rules 업데이트 필요")
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
    print("   1. app_config 컬렉션: 모든 사용자 읽기 가능 (로그인 전)")
    print("   2. fcm_tokens 컬렉션: 인증된 사용자가 자신의 토큰만 관리")
    print("   3. approval_requests 컬렉션: 자신의 승인 요청만 조회/수정")
    print("   4. users 컬렉션: 자신의 문서만 읽기/쓰기")
    print("   5. 기타 컬렉션: 자신의 데이터(userId 기반)만 접근\n")
    
    print("🔍 해결되는 문제:")
    print("   ❌ PERMISSION_DENIED: fcm_tokens 컬렉션 접근 불가")
    print("   ✅ 인증된 사용자가 자신의 FCM 토큰 관리 가능")
    print("   ✅ 기기 승인 요청 생성/조회 가능")
    print("   ✅ 보안: 다른 사용자의 토큰/데이터 접근 불가\n")

if __name__ == '__main__':
    project_id = get_project_id()
    
    if project_id:
        print(f"\n🌐 Firebase Console 바로가기:")
        print(f"   https://console.firebase.google.com/project/{project_id}/firestore/rules")
    
    display_updated_security_rules()
    
    print("\n⚠️  중요: Security Rules 변경 후 앱을 재시작하세요!")
    print("   - 변경사항이 즉시 반영됩니다 (최대 1분 소요)")
    print("   - 앱 재시작 후 FCM 토큰 저장이 정상 작동합니다\n")
