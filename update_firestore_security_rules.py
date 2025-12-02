#!/usr/bin/env python3
"""
Firestore 보안 규칙 업데이트 스크립트

FCM 기기 승인 기능을 위한 필수 컬렉션 권한 추가:
- fcm_approval_notification_queue
- device_approval_requests
"""

import json
import subprocess
import sys

# google-services.json에서 project_id 추출
try:
    with open('/opt/flutter/google-services.json', 'r') as f:
        google_services = json.load(f)
        project_id = google_services['project_info']['project_id']
        print(f"✅ Firebase 프로젝트 ID: {project_id}")
except Exception as e:
    print(f"❌ google-services.json 읽기 실패: {e}")
    sys.exit(1)

# Firestore 보안 규칙 (FCM 승인 기능 포함)
firestore_rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // 사용자 문서 - 본인만 읽기/쓰기
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 단말번호 - 본인만 읽기/쓰기
    match /my_extensions/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 통화 기록 - 본인만 읽기/쓰기
    match /call_history/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 연락처 - 본인만 읽기/쓰기
    match /contacts/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // 착신전환 정보 - 본인만 읽기/쓰기
    match /call_forward_info/{docId} {
      allow read, write: if request.auth != null && docId.matches('^' + request.auth.uid + '_.*');
    }
    
    // 🔥 FCM 토큰 - 본인만 읽기/쓰기
    match /fcm_tokens/{docId} {
      allow read, write: if request.auth != null && docId.matches('^' + request.auth.uid + '_.*');
    }
    
    // 🔥 기기 승인 요청 - 본인만 읽기/쓰기
    match /device_approval_requests/{docId} {
      allow read, write: if request.auth != null && docId.matches('^' + request.auth.uid + '_.*');
    }
    
    // 🔥 FCM 승인 알림 큐 - 인증된 사용자 읽기/쓰기
    match /fcm_approval_notification_queue/{docId} {
      allow read, write: if request.auth != null;
    }
    
    // 설정 정보 - 본인만 읽기/쓰기
    match /settings/{docId} {
      allow read, write: if request.auth != null && docId.matches('^' + request.auth.uid + '(_.*)?');
    }
    
    // 기타 모든 문서 - 기본 거부
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
"""

print()
print("=" * 80)
print("📝 Firestore 보안 규칙")
print("=" * 80)
print(firestore_rules)
print("=" * 80)
print()

# 규칙 파일 생성
rules_file = '/tmp/firestore.rules'
try:
    with open(rules_file, 'w') as f:
        f.write(firestore_rules)
    print(f"✅ 보안 규칙 파일 생성: {rules_file}")
except Exception as e:
    print(f"❌ 파일 생성 실패: {e}")
    sys.exit(1)

print()
print("=" * 80)
print("🚀 Firestore 보안 규칙 배포 방법")
print("=" * 80)
print()
print("옵션 1️⃣: Firebase CLI 사용 (권장)")
print("─" * 80)
print(f"  1. Firebase CLI 설치: npm install -g firebase-tools")
print(f"  2. 로그인: firebase login")
print(f"  3. 규칙 배포: firebase deploy --only firestore:rules --project {project_id}")
print()
print("옵션 2️⃣: Firebase Console 사용 (수동)")
print("─" * 80)
print(f"  1. Firebase Console 접속: https://console.firebase.google.com/project/{project_id}/firestore/rules")
print(f"  2. 위의 보안 규칙 복사")
print(f"  3. 'Rules' 탭에서 규칙 붙여넣기")
print(f"  4. '게시' 버튼 클릭")
print()
print("=" * 80)
print()

print("✅ 스크립트 완료")
print()
print("⚠️  주의: 보안 규칙을 적용한 후 앱을 재시작하세요.")
