#!/usr/bin/env python3
"""
Firebase Firestore 데이터베이스 청소 스크립트

테스트를 위해 Firestore의 특정 컬렉션 또는 전체 데이터를 삭제합니다.
"""

import sys
import os
import warnings

# Suppress Python version and SSL warnings
warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', message='urllib3 v2 only supports OpenSSL')

# Firebase Admin SDK 임포트
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    print("✅ firebase-admin 임포트 성공")
except ImportError as e:
    print(f"❌ firebase-admin 패키지가 설치되지 않았습니다: {e}")
    print("📦 설치 명령어: pip install firebase-admin==7.1.0")
    sys.exit(1)

# Firebase Admin SDK 키 파일 경로
ADMIN_SDK_PATH = "/opt/flutter/firebase-admin-sdk.json"

def initialize_firebase():
    """Firebase 초기화"""
    if not os.path.exists(ADMIN_SDK_PATH):
        print(f"❌ Firebase Admin SDK 키 파일을 찾을 수 없습니다: {ADMIN_SDK_PATH}")
        print("💡 Firebase Console에서 서비스 계정 키를 다운로드하고 업로드해주세요.")
        sys.exit(1)
    
    try:
        cred = credentials.Certificate(ADMIN_SDK_PATH)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        print("✅ Firebase 초기화 완료")
        return firestore.client()
    except Exception as e:
        print(f"❌ Firebase 초기화 실패: {e}")
        sys.exit(1)

def delete_collection(db, collection_name, batch_size=100):
    """컬렉션 전체 삭제"""
    print(f"\n🗑️  '{collection_name}' 컬렉션 삭제 중...")
    
    coll_ref = db.collection(collection_name)
    deleted_count = 0
    
    while True:
        docs = coll_ref.limit(batch_size).stream()
        deleted = 0
        
        for doc in docs:
            print(f"   - 삭제 중: {doc.id}")
            doc.reference.delete()
            deleted += 1
            deleted_count += 1
        
        if deleted < batch_size:
            break
    
    print(f"✅ '{collection_name}' 컬렉션 삭제 완료 (총 {deleted_count}개 문서)")
    return deleted_count

def delete_user_data(db, user_id):
    """특정 사용자 데이터만 삭제"""
    print(f"\n🗑️  사용자 '{user_id}' 데이터 삭제 중...")
    
    total_deleted = 0
    
    # users 컬렉션
    try:
        db.collection('users').document(user_id).delete()
        print(f"   ✅ users/{user_id} 삭제")
        total_deleted += 1
    except Exception as e:
        print(f"   ⚠️  users/{user_id} 삭제 실패: {e}")
    
    # fcm_tokens 컬렉션 (userId로 시작하는 문서들)
    fcm_docs = db.collection('fcm_tokens').where(filter=firestore.FieldFilter('userId', '==', user_id)).stream()
    for doc in fcm_docs:
        doc.reference.delete()
        print(f"   ✅ fcm_tokens/{doc.id} 삭제")
        total_deleted += 1
    
    # fcm_approval_requests 컬렉션
    approval_docs = db.collection('fcm_approval_requests').where(filter=firestore.FieldFilter('userId', '==', user_id)).stream()
    for doc in approval_docs:
        doc.reference.delete()
        print(f"   ✅ fcm_approval_requests/{doc.id} 삭제")
        total_deleted += 1
    
    # fcm_approval_notification_queue 컬렉션
    queue_docs = db.collection('fcm_approval_notification_queue').where(filter=firestore.FieldFilter('userId', '==', user_id)).stream()
    for doc in queue_docs:
        doc.reference.delete()
        print(f"   ✅ fcm_approval_notification_queue/{doc.id} 삭제")
        total_deleted += 1
    
    # my_extensions 서브컬렉션
    ext_docs = db.collection('users').document(user_id).collection('my_extensions').stream()
    for doc in ext_docs:
        doc.reference.delete()
        print(f"   ✅ users/{user_id}/my_extensions/{doc.id} 삭제")
        total_deleted += 1
    
    print(f"✅ 사용자 '{user_id}' 데이터 삭제 완료 (총 {total_deleted}개)")
    return total_deleted

def list_collections(db):
    """모든 컬렉션 목록 조회"""
    print("\n📋 Firestore 컬렉션 목록:")
    collections = db.collections()
    for coll in collections:
        count = len(list(coll.limit(1000).stream()))
        print(f"   - {coll.id}: {count}개 문서")

def main():
    """메인 함수"""
    print("=" * 60)
    print("🧹 Firebase Firestore 데이터베이스 청소 스크립트")
    print("=" * 60)
    
    # Firebase 초기화
    db = initialize_firebase()
    
    # 메뉴 표시
    print("\n📋 청소 옵션:")
    print("1. 전체 데이터베이스 청소 (모든 컬렉션 삭제)")
    print("2. FCM 관련 데이터만 삭제 (fcm_tokens, fcm_approval_requests, fcm_approval_notification_queue)")
    print("3. 특정 사용자 데이터만 삭제")
    print("4. 컬렉션 목록만 조회")
    print("5. 취소")
    
    choice = input("\n선택 (1-5): ").strip()
    
    if choice == "1":
        # 전체 데이터베이스 청소
        confirm = input("\n⚠️  경고: 모든 데이터가 삭제됩니다! 계속하시겠습니까? (yes/no): ").strip().lower()
        if confirm == "yes":
            collections_to_delete = [
                'users',
                'fcm_tokens',
                'fcm_approval_requests',
                'fcm_approval_notification_queue',
                'phonebook',
                'my_extensions',
                'call_history',
            ]
            total = 0
            for coll in collections_to_delete:
                total += delete_collection(db, coll)
            print(f"\n✅ 전체 청소 완료 (총 {total}개 문서 삭제)")
        else:
            print("❌ 취소되었습니다.")
    
    elif choice == "2":
        # FCM 관련 데이터만 삭제
        confirm = input("\n⚠️  FCM 관련 데이터를 삭제합니다. 계속하시겠습니까? (yes/no): ").strip().lower()
        if confirm == "yes":
            total = 0
            total += delete_collection(db, 'fcm_tokens')
            total += delete_collection(db, 'fcm_approval_requests')
            total += delete_collection(db, 'fcm_approval_notification_queue')
            print(f"\n✅ FCM 데이터 청소 완료 (총 {total}개 문서 삭제)")
        else:
            print("❌ 취소되었습니다.")
    
    elif choice == "3":
        # 특정 사용자 데이터만 삭제
        user_id = input("\n삭제할 사용자 ID (예: kakao_4550398105): ").strip()
        if user_id:
            confirm = input(f"\n⚠️  사용자 '{user_id}'의 모든 데이터를 삭제합니다. 계속하시겠습니까? (yes/no): ").strip().lower()
            if confirm == "yes":
                delete_user_data(db, user_id)
            else:
                print("❌ 취소되었습니다.")
        else:
            print("❌ 사용자 ID를 입력해주세요.")
    
    elif choice == "4":
        # 컬렉션 목록만 조회
        list_collections(db)
    
    else:
        print("❌ 취소되었습니다.")
    
    print("\n" + "=" * 60)
    print("✅ 스크립트 실행 완료")
    print("=" * 60)

if __name__ == "__main__":
    main()
