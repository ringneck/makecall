#!/usr/bin/env python3
"""
Firestore Security Rules Generator - Version 2 (올바른 컬렉션 구조)
===============================================================

문제: permission-denied 에러 발생
원인: 서브컬렉션 구조 가정 vs 실제 단일 컬렉션 구조 불일치
해결: userId 필드 기반 접근 제어로 변경

컬렉션 구조:
- my_extensions/{docId}         → userId 필드 사용
- call_history/{docId}           → userId 필드 사용
- contacts/{docId}               → userId 필드 사용
- phonebook_contacts/{docId}     → userId 필드 사용
- call_forward_info/{userId_extensionNumber}
- fcm_tokens/{userId_deviceId_platform}
- device_approval_requests/{requestId}
- fcm_approval_notification_queue/{queueId}
"""

def generate_firestore_rules():
    """Firestore 보안 규칙 생성 (단일 컬렉션 구조에 맞게 수정)"""
    
    rules = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // 1. users 컬렉션 - 사용자 계정 정보
    // ============================================
    match /users/{userId} {
      // 본인 문서만 읽기/쓰기 가능
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ============================================
    // 2. my_extensions 컬렉션 - 단말번호 정보
    // ============================================
    match /my_extensions/{documentId} {
      // 로그인한 사용자이고, 문서의 userId 필드가 본인과 일치하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
      // 새 문서 생성 시 (resource.data 없음)
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.userId;
    }
    
    // ============================================
    // 3. call_history 컬렉션 - 통화 기록
    // ============================================
    match /call_history/{documentId} {
      // 로그인한 사용자이고, 문서의 userId 필드가 본인과 일치하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
      // 새 문서 생성 시
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.userId;
    }
    
    // ============================================
    // 4. contacts 컬렉션 - 연락처
    // ============================================
    match /contacts/{documentId} {
      // 로그인한 사용자이고, 문서의 userId 필드가 본인과 일치하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
      // 새 문서 생성 시
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.userId;
    }
    
    // ============================================
    // 5. phonebook_contacts 컬렉션 - 주소록 연락처
    // ============================================
    match /phonebook_contacts/{documentId} {
      // 로그인한 사용자이고, 문서의 userId 필드가 본인과 일치하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
      // 새 문서 생성 시
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.userId;
    }
    
    // ============================================
    // 6. call_forward_info 컬렉션 - 착신전환 정보
    // ============================================
    match /call_forward_info/{documentId} {
      // documentId 형식: {userId}_{extensionNumber}
      // 로그인한 사용자이고, documentId가 본인 userId로 시작하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && documentId.matches('^' + request.auth.uid + '_.*');
    }
    
    // ============================================
    // 7. fcm_tokens 컬렉션 - FCM 토큰 관리
    // ============================================
    match /fcm_tokens/{documentId} {
      // documentId 형식: {userId}_{deviceId}_{platform}
      // 로그인한 사용자이고, documentId가 본인 userId로 시작하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && documentId.matches('^' + request.auth.uid + '_.*');
    }
    
    // ============================================
    // 8. device_approval_requests 컬렉션 - 기기 승인 요청
    // ============================================
    match /device_approval_requests/{requestId} {
      // 로그인한 사용자이고, 문서의 userId 필드가 본인과 일치하면 읽기/쓰기 가능
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
      // 새 문서 생성 시
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.userId;
    }
    
    // ============================================
    // 9. fcm_approval_notification_queue - FCM 승인 알림 큐
    // ============================================
    match /fcm_approval_notification_queue/{queueId} {
      // 로그인한 모든 사용자가 읽기/쓰기 가능 (알림 전송용)
      allow read, write: if request.auth != null;
    }
    
    // ============================================
    // 10. settings 컬렉션 - 사용자 설정
    // ============================================
    match /settings/{userId} {
      // 본인 설정만 읽기/쓰기 가능
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ============================================
    // 기타 모든 문서 - 기본 거부
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}"""
    
    return rules

def print_deployment_instructions():
    """배포 방법 안내"""
    print("\n" + "="*70)
    print("📋 Firestore Security Rules 배포 방법")
    print("="*70)
    
    print("\n🔥 방법 1: Firebase Console (권장)")
    print("-" * 70)
    print("1. Firebase Console 접속:")
    print("   https://console.firebase.google.com/project/makecallio/firestore/rules")
    print("\n2. 위의 규칙 전체를 복사하여 붙여넣기")
    print("\n3. '게시' 버튼 클릭")
    print("\n4. 1-2분 후 앱 재시작")
    
    print("\n\n⚡ 방법 2: Firebase CLI")
    print("-" * 70)
    print("$ firebase deploy --only firestore:rules --project makecallio")
    
    print("\n" + "="*70)
    print("⚠️  주의사항")
    print("="*70)
    print("• 규칙 적용 후 1-2분 대기 필요 (전파 시간)")
    print("• 앱을 완전히 종료 후 재시작")
    print("• userId 필드가 없는 문서는 접근 불가")
    print("• 테스트 시 로그에서 permission-denied 에러 사라지는지 확인")
    
    print("\n" + "="*70)
    print("✅ 수정된 내용")
    print("="*70)
    print("• 서브컬렉션 구조 → 단일 컬렉션 구조로 변경")
    print("• resource.data.userId 필드 기반 접근 제어")
    print("• call_forward_info: documentId 패턴 매칭 (userId_extensionNumber)")
    print("• fcm_tokens: documentId 패턴 매칭 (userId_deviceId_platform)")
    print("• 모든 주요 컬렉션에 create 권한 추가")
    print("="*70)

def main():
    print("🔧 Firestore Security Rules Generator v2")
    print("="*70)
    print("프로젝트: makecallio")
    print("수정 이유: permission-denied 에러 해결")
    print("="*70)
    
    # 규칙 생성
    rules = generate_firestore_rules()
    
    # 파일로 저장
    rules_file = "firestore.rules"
    with open(rules_file, "w", encoding="utf-8") as f:
        f.write(rules)
    
    print(f"\n✅ 보안 규칙이 '{rules_file}' 파일로 저장되었습니다.")
    print("\n" + "="*70)
    print("📄 생성된 Firestore Security Rules:")
    print("="*70)
    print(rules)
    
    # 배포 방법 안내
    print_deployment_instructions()

if __name__ == "__main__":
    main()
