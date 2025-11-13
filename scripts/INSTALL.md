# 🔧 로컬 환경 설치 가이드 (macOS/Linux)

## 방법 1: pip3로 설치 (권장)

```bash
# Python 3 pip 사용
pip3 install --user firebase-admin

# 또는 python3 -m pip 사용
python3 -m pip install --user firebase-admin
```

## 방법 2: Homebrew Python 사용 (macOS)

시스템 Python 대신 Homebrew Python을 사용하면 더 깔끔합니다:

```bash
# Homebrew 설치 (없는 경우)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Python 3 설치
brew install python3

# Firebase Admin 설치
pip3 install firebase-admin
```

## 방법 3: 가상 환경 사용 (권장 - 프로젝트별 격리)

```bash
# 프로젝트 디렉토리로 이동
cd ~/makecall/makecall

# 가상 환경 생성
python3 -m venv venv

# 가상 환경 활성화
source venv/bin/activate

# Firebase Admin 설치
pip install firebase-admin

# 스크립트 실행
cd scripts
python3 check_firestore_state.py

# 작업 완료 후 비활성화
deactivate
```

## ⚠️ PATH 경고 해결

만약 다음과 같은 경고가 나온다면:

```
WARNING: The scripts pip, pip3 and pip3.9 are installed in 
'/Users/norman.southcastle/Library/Python/3.9/bin' which is not on PATH.
```

**해결 방법 1: PATH에 추가 (영구 적용)**

```bash
# .zshrc 또는 .bash_profile에 추가
echo 'export PATH="$HOME/Library/Python/3.9/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**해결 방법 2: --user 플래그 사용**

```bash
# 이미 설치했다면 이 방법을 사용했을 가능성이 높음
python3 -m pip install --user firebase-admin
```

## 🧪 설치 확인

```bash
# Python 버전 확인
python3 --version

# Firebase Admin 설치 확인
python3 -c "import firebase_admin; print('✅ Firebase Admin 설치 완료')"
```

## 📋 Firebase Admin SDK 파일 준비

1. **Firebase Console** 접속: https://console.firebase.google.com/
2. 프로젝트 선택
3. **Project Settings** (⚙️) → **Service accounts**
4. **Python** 선택 (중요!)
5. **"Generate new private key"** 클릭
6. 다운로드한 파일을 `firebase-admin-sdk.json`으로 이름 변경
7. 다음 위치 중 하나에 배치:
   - `~/makecall/makecall/firebase-admin-sdk.json`
   - `~/makecall/makecall/scripts/firebase-admin-sdk.json`

```bash
# 다운로드 폴더에서 복사
cp ~/Downloads/makecall-*.json ~/makecall/makecall/firebase-admin-sdk.json
```

## 🚀 스크립트 실행

```bash
cd ~/makecall/makecall/scripts

# Firestore 상태 확인
python3 check_firestore_state.py

# 테스트 데이터 정리
python3 cleanup_test_data.py
```

## 💡 권장 워크플로우

**가상 환경 사용 (프로젝트 격리, 권장)**

```bash
# 1회 설정
cd ~/makecall/makecall
python3 -m venv venv
source venv/bin/activate
pip install firebase-admin

# 매번 사용시
cd ~/makecall/makecall
source venv/bin/activate
cd scripts
python3 check_firestore_state.py
deactivate
```

## 🔧 문제 해결

### ImportError: No module named 'firebase_admin'

```bash
# 다시 설치
python3 -m pip install --user firebase-admin

# 또는 가상 환경에서
source venv/bin/activate
pip install firebase-admin
```

### Permission denied

```bash
# --user 플래그 사용
python3 -m pip install --user firebase-admin
```

### Multiple Python versions

```bash
# 사용 중인 Python 확인
which python3
python3 --version

# pip가 올바른 Python에 설치하는지 확인
python3 -m pip --version
```

---

## 📞 도움이 필요하신가요?

- [Firebase Admin SDK 문서](https://firebase.google.com/docs/admin/setup)
- [Python 가상 환경 가이드](https://docs.python.org/3/tutorial/venv.html)
