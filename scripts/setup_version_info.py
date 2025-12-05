#!/usr/bin/env python3
"""
Firestore에 버전 정보 초기 설정 스크립트

사용법:
    python3 scripts/setup_version_info.py

기능:
- app_config/version_info 문서 생성
- 버전 정보 필드 설정
"""

import sys
import os

# Firebase Admin SDK 임포트
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    print("✅ firebase-admin imported successfully")
except ImportError as e:
    print(f"❌ Failed to import firebase-admin: {e}")
    print("📦 Installing firebase-admin...")
    os.system("pip install firebase-admin==7.1.0")
    import firebase_admin
    from firebase_admin import credentials, firestore

def find_firebase_admin_key():
    """Firebase Admin SDK 키 파일 찾기"""
    possible_paths = [
        '/opt/flutter/firebase-admin-sdk.json',
        '/opt/flutter/makecallio-firebase-adminsdk.json',
    ]
    
    # /opt/flutter/ 디렉토리에서 adminsdk 포함된 파일 찾기
    try:
        flutter_dir = '/opt/flutter/'
        if os.path.exists(flutter_dir):
            for filename in os.listdir(flutter_dir):
                if 'adminsdk' in filename.lower() and filename.endswith('.json'):
                    possible_paths.append(os.path.join(flutter_dir, filename))
    except Exception as e:
        print(f"⚠️ Error scanning /opt/flutter/: {e}")
    
    for path in possible_paths:
        if os.path.exists(path):
            print(f"✅ Found Firebase Admin SDK key: {path}")
            return path
    
    print("❌ Firebase Admin SDK key not found")
    print("📁 Searched paths:")
    for path in possible_paths:
        print(f"   - {path}")
    return None

def setup_version_info():
    """Firestore에 버전 정보 설정"""
    
    # Firebase Admin SDK 키 파일 찾기
    key_path = find_firebase_admin_key()
    if not key_path:
        print("\n❌ Firebase Admin SDK 키 파일을 찾을 수 없습니다.")
        print("📝 Firebase Console에서 키를 다운로드하여 /opt/flutter/ 에 저장하세요.")
        sys.exit(1)
    
    # Firebase 초기화
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            print("✅ Firebase Admin SDK initialized")
    except Exception as e:
        print(f"❌ Firebase initialization failed: {e}")
        sys.exit(1)
    
    # Firestore 클라이언트
    db = firestore.client()
    
    # 버전 정보 데이터
    version_data = {
        'latest_version': '1.0.2',  # 최신 버전
        'minimum_version': '1.0.0', # 최소 지원 버전
        'update_message': '새로운 기능이 추가되었습니다!\n\n• 다크모드 지원\n• 성능 개선\n• 버그 수정',
        'force_update': False,      # 강제 업데이트 여부
    }
    
    print("\n📝 Setting up version info in Firestore...")
    print(f"   Collection: app_config")
    print(f"   Document: version_info")
    print(f"   Data:")
    for key, value in version_data.items():
        print(f"      - {key}: {value}")
    
    # Firestore에 저장
    try:
        doc_ref = db.collection('app_config').document('version_info')
        
        # 기존 문서 확인
        if doc_ref.get().exists:
            print("\n⚠️  version_info 문서가 이미 존재합니다.")
            response = input("덮어쓰시겠습니까? (y/N): ")
            if response.lower() != 'y':
                print("❌ 작업이 취소되었습니다.")
                return
        
        # 문서 저장
        doc_ref.set(version_data)
        print("\n✅ 버전 정보가 성공적으로 저장되었습니다!")
        
        # 저장된 데이터 확인
        saved_doc = doc_ref.get()
        if saved_doc.exists:
            print("\n📦 Saved data:")
            saved_data = saved_doc.to_dict()
            for key, value in saved_data.items():
                print(f"   - {key}: {value}")
        
        print("\n🎉 설정 완료!")
        print("\n📱 앱에서 버전 체크를 테스트하세요:")
        print("   1. pubspec.yaml의 version을 1.0.0 또는 1.0.1로 설정")
        print("   2. 앱 재시작")
        print("   3. MainScreen 진입 시 업데이트 안내 BottomSheet 표시 확인")
        
    except Exception as e:
        print(f"\n❌ Firestore 저장 실패: {e}")
        sys.exit(1)

if __name__ == '__main__':
    print("=" * 60)
    print("🔄 Firestore 버전 정보 설정 스크립트")
    print("=" * 60)
    print()
    
    setup_version_info()
