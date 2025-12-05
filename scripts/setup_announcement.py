#!/usr/bin/env python3
"""
Firestore 공지사항 설정 스크립트

이 스크립트는 Firebase Firestore의 app_config/announcements 컬렉션에
샘플 공지사항 데이터를 생성합니다.

실행 방법:
    python3 scripts/setup_announcement.py
"""

import sys
from datetime import datetime, timedelta

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
        # 이미 초기화되어 있는지 확인
        firebase_admin.get_app()
        print("ℹ️ Firebase already initialized")
    except ValueError:
        # 초기화되지 않은 경우 새로 초기화
        cred = credentials.Certificate('/opt/flutter/firebase-admin-sdk.json')
        firebase_admin.initialize_app(cred)
        print("✅ Firebase initialized successfully")

def setup_announcement():
    """Firestore에 공지사항 샘플 데이터 생성"""
    try:
        initialize_firebase()
        db = firestore.client()
        
        # 현재 시간 기준 공지사항 기간 설정
        now = datetime.now()
        start_date = now - timedelta(days=1)  # 어제부터
        end_date = now + timedelta(days=30)   # 30일 후까지
        
        # 샘플 공지사항 데이터
        announcement_data = {
            'title': '새로운 기능이 추가되었습니다! 🎉',
            'message': '''안녕하세요, MAKECALL 사용자 여러분!

새로운 업데이트가 적용되었습니다:

• 다크모드 UI 개선
• 소셜 로그인 안정성 향상
• 공지사항 시스템 추가
• 버전 체크 기능 개선

더욱 향상된 서비스로 찾아뵙겠습니다.
감사합니다.''',
            'priority': 'normal',  # high, normal, low
            'is_active': True,
            'start_date': start_date,
            'end_date': end_date,
            'created_at': firestore.SERVER_TIMESTAMP,
        }
        
        # Firestore에 공지사항 저장
        # 경로: app_config/announcements/items/{auto-id}
        doc_ref = db.collection('app_config').document('announcements').collection('items').document()
        doc_ref.set(announcement_data)
        
        print("\n✅ 공지사항 데이터 생성 완료!")
        print(f"\n📢 공지사항 ID: {doc_ref.id}")
        print(f"   제목: {announcement_data['title']}")
        print(f"   우선순위: {announcement_data['priority']}")
        print(f"   활성 상태: {announcement_data['is_active']}")
        print(f"   시작일: {start_date.strftime('%Y-%m-%d')}")
        print(f"   종료일: {end_date.strftime('%Y-%m-%d')}")
        
        print("\n✅ Firestore 구조:")
        print("   app_config (collection)")
        print("   └── announcements (document)")
        print("       └── items (collection)")
        print(f"           └── {doc_ref.id} (document)")
        
        print("\n📝 테스트 방법:")
        print("   1. Flutter 앱 실행")
        print("   2. 로그인 후 MainScreen 진입")
        print("   3. 공지사항 BottomSheet 자동 표시 확인")
        print("   4. '다시 보지 않기' 체크박스 테스트")
        print("   5. 닫기 버튼 (X) 동작 확인")
        
        print("\n💡 공지사항 관리:")
        print("   - 새 공지 추가: Firebase Console에서 items 컬렉션에 문서 추가")
        print("   - 공지 비활성화: is_active를 false로 변경")
        print("   - 공지 기간 조정: start_date, end_date 수정")
        print("   - 우선순위 변경: priority를 'high', 'normal', 'low' 중 선택")
        
    except Exception as e:
        print(f"\n❌ 에러 발생: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    setup_announcement()
