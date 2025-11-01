#!/usr/bin/env python3
"""
Firebase Storage 보안 규칙 설정 스크립트

프로필 이미지 업로드를 위한 Firebase Storage 보안 규칙을 설정합니다.
"""

import sys
import json
import subprocess

def load_firebase_config():
    """Firebase Admin SDK 설정 로드"""
    try:
        with open('/opt/flutter/firebase-admin-sdk.json', 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("❌ Firebase Admin SDK 파일을 찾을 수 없습니다: /opt/flutter/firebase-admin-sdk.json")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Firebase Admin SDK JSON 파싱 실패: {e}")
        sys.exit(1)

def get_project_id(config):
    """Firebase 프로젝트 ID 추출"""
    project_id = config.get('project_id')
    if not project_id:
        print("❌ Firebase 설정에서 project_id를 찾을 수 없습니다")
        sys.exit(1)
    return project_id

def print_storage_rules():
    """Firebase Storage 보안 규칙 출력"""
    rules = """rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // 프로필 이미지: 인증된 사용자만 자신의 이미지 업로드/삭제 가능
    match /profile_images/{userId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // 기타 파일: 인증된 사용자만 접근 가능
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}"""
    return rules

def save_rules_to_file(rules, project_id):
    """보안 규칙을 파일로 저장"""
    output_file = "firebase_storage_rules.txt"
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("Firebase Storage 보안 규칙\n")
            f.write("=" * 80 + "\n\n")
            
            f.write(f"📦 프로젝트 ID: {project_id}\n")
            f.write(f"🔗 Firebase Console: https://console.firebase.google.com/project/{project_id}/storage/rules\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("복사할 보안 규칙 (아래 전체 내용을 복사하세요)\n")
            f.write("=" * 80 + "\n\n")
            
            f.write(rules)
            f.write("\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("설정 방법\n")
            f.write("=" * 80 + "\n\n")
            
            f.write("1단계: Firebase Console 접속\n")
            f.write(f"   {project_id}/storage/rules\n\n")
            
            f.write("2단계: 위의 보안 규칙 복사\n")
            f.write("   - 위의 'rules_version'부터 마지막 '}}'까지 전체 복사\n\n")
            
            f.write("3단계: Firebase Console에 붙여넣기\n")
            f.write("   - Storage → Rules 탭으로 이동\n")
            f.write("   - 기존 규칙을 모두 삭제하고 복사한 규칙 붙여넣기\n\n")
            
            f.write("4단계: '게시' 버튼 클릭\n")
            f.write("   - 변경사항 저장 및 적용\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("보안 규칙 설명\n")
            f.write("=" * 80 + "\n\n")
            
            f.write("✅ 프로필 이미지 (profile_images/{userId}.jpg):\n")
            f.write("   - 모든 사용자가 조회 가능 (read: if true)\n")
            f.write("   - 인증된 사용자가 자신의 이미지만 업로드/삭제 가능\n")
            f.write("   - request.auth.uid == userId 조건으로 본인 확인\n\n")
            
            f.write("✅ 기타 파일 (/{allPaths=**}):\n")
            f.write("   - 인증된 사용자만 읽기/쓰기 가능\n")
            f.write("   - request.auth != null 조건\n\n")
            
        return output_file
    except Exception as e:
        print(f"❌ 파일 저장 실패: {e}")
        return None

def main():
    print("🔥 Firebase Storage 보안 규칙 설정")
    print("=" * 60)
    
    # Firebase 설정 로드
    config = load_firebase_config()
    project_id = get_project_id(config)
    
    print(f"✅ Firebase 프로젝트 ID: {project_id}")
    print()
    
    # Storage 보안 규칙 출력
    rules = print_storage_rules()
    
    print("📋 Firebase Storage 보안 규칙:")
    print("-" * 60)
    print(rules)
    print("-" * 60)
    print()
    
    # 파일로 저장
    output_file = save_rules_to_file(rules, project_id)
    
    if output_file:
        print(f"💾 보안 규칙을 파일로 저장했습니다: {output_file}")
        print()
    
    print("⚠️  수동 설정 필요:")
    print(f"1. Firebase Console 접속: https://console.firebase.google.com/project/{project_id}/storage/rules")
    print("2. 위의 규칙을 복사하여 Storage Rules 탭에 붙여넣기")
    print("3. '게시' 버튼 클릭하여 규칙 적용")
    print()
    
    print("💡 규칙 설명:")
    print("   - profile_images/{userId}.jpg: 인증된 사용자가 자신의 프로필 이미지만 업로드/삭제 가능")
    print("   - 모든 사용자가 프로필 이미지를 조회할 수 있음 (read: true)")
    print("   - 기타 파일: 인증된 사용자만 읽기/쓰기 가능")
    print()
    
    print("✅ Firebase Storage 보안 규칙 설정 완료")
    print()
    print("🔗 빠른 링크:")
    print(f"   Firebase Console: https://console.firebase.google.com/project/{project_id}/storage")
    
    if output_file:
        print()
        print(f"📥 다운로드: {output_file}")

if __name__ == "__main__":
    main()
