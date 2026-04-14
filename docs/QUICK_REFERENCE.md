# NotepadNext: 빠른 참고 (치트시트)

## 🚀 자주 사용하는 명령어

### 빌드

```bash
# 개발 빌드 (디버그)
xcodebuild build -scheme NotepadNext -configuration Debug

# 릴리스 빌드
xcodebuild build -scheme NotepadNext -configuration Release

# 특정 아키텍처 (Apple Silicon)
xcodebuild build -scheme NotepadNext -destination 'platform=macOS,arch=arm64'

# 빠른 개발 빌드 (권장)
./Scripts/fast-build.sh
```

### 테스트

```bash
# 모든 테스트
xcodebuild test -scheme NotepadNext

# 특정 테스트 타겟
xcodebuild test -scheme NotepadNextTests

# 성능 테스트
xcodebuild test -scheme NotepadNext -testPlan PerformanceTests

# 빠른 단위 테스트
./Scripts/fast-test.sh unit

# UI 테스트
./Scripts/fast-test.sh ui

# 스냅샷 테스트
./Scripts/fast-test.sh snapshot

# 병렬 테스트 실행
xcodebuild test -parallel-testing-enabled YES
```

### 코드 스타일

```bash
# 포맷 확인
swift-format lint -r Sources Tests

# 자동 포맷팅
swift-format format -r Sources Tests

# SwiftLint 실행
swiftlint lint

# SwiftLint 자동 수정
swiftlint autocorrect
```

### 버전 관리

```bash
# 현재 버전 확인
grep 'let version = ' Sources/NotepadNext/App/Version.swift

# 패치 버전 증가
./Scripts/version.sh bump patch

# 마이너 버전 증가
./Scripts/version.sh bump minor

# 메이저 버전 증가
./Scripts/version.sh bump major

# 특정 버전 설정
./Scripts/version.sh set 2.0.0
```

### 릴리스

```bash
# 릴리스 전 체크리스트
./Scripts/pre-release-checklist.sh

# 버전 업데이트
./Scripts/version.sh set 1.2.3

# DMG 생성
./Scripts/build-dmg.sh dist/NotepadNext.app dist/NotepadNext.dmg

# 코드 서명
./Scripts/sign-app.sh dist/NotepadNext.app "Developer ID Application: Name"

# 공증
./Scripts/notarize-app.sh dist/NotepadNext.dmg $APPLE_ID $PASSWORD $TEAM_ID

# CHANGELOG 생성
./Scripts/generate-changelog.sh 1.2.3

# 태그 생성
git tag -a v1.2.3 -m "Release v1.2.3"

# 푸시 (GitHub Actions 트리거)
git push origin main --tags
```

### Git 워크플로우

```bash
# 기능 개발 시작
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# 커밋
git add .
git commit -m "feat(scope): description"

# PR 준비
git push -u origin feature/my-feature
# GitHub에서 PR 생성

# PR 병합 후 정리
git checkout develop
git pull origin develop
git branch -d feature/my-feature
git push origin --delete feature/my-feature

# 릴리스 준비
git checkout main
git pull origin develop
# ... 버전 업데이트, CHANGELOG ...
git commit -am "chore(release): v1.2.3"
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin main --tags
```

---

## 📁 주요 파일 위치

### 설정
| 파일 | 목적 |
|------|------|
| `Package.swift` | SPM 의존성 |
| `build.xcconfig` | 빌드 설정 |
| `.swiftformat` | 포맷 규칙 |
| `.swiftlint.yml` | Lint 규칙 |
| `.gitignore` | Git 무시 파일 |

### 소스 코드
| 경로 | 내용 |
|------|------|
| `Sources/NotepadNext/` | 메인 앱 |
| `Sources/NotepadNextCore/` | 핵심 라이브러리 |
| `Sources/SyntaxHighlighter/` | 구문 강조 |
| `Tests/` | 모든 테스트 |

### 자동화
| 파일 | 목적 |
|------|------|
| `.github/workflows/build.yml` | 빌드 자동화 |
| `.github/workflows/test.yml` | 테스트 자동화 |
| `.github/workflows/lint.yml` | 코드 스타일 확인 |
| `.github/workflows/release.yml` | 릴리스 자동화 |
| `Scripts/*.sh` | 보조 스크립트 |

---

## 🔧 설정 변경

### 최소 macOS 버전 변경
```bash
# Package.swift
.macOS(.v12)  // 12.0으로 변경

# build.xcconfig
MACOSX_DEPLOYMENT_TARGET = 12.0
```

### 의존성 추가
```swift
// Package.swift에 dependencies 추가
.package(url: "https://github.com/...", from: "1.0.0")

// targets 배열에 추가
.product(name: "ProductName", package: "package-name")
```

### 앱 버번 변경
```swift
// Sources/NotepadNext/App/Version.swift
static let current = "1.2.3"
```

### 서명 아이덴티티 변경
```bash
# 현재 ID 확인
security find-identity -v -p codesigning

# scripts/sign-app.sh에서 ID 지정
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" app.app
```

---

## 🐛 일반적인 문제 해결

### 빌드 오류

```bash
# 캐시 정리
rm -rf build ~/Library/Developer/Xcode/DerivedData/NotepadNext*

# 의존성 재설정
rm Package.resolved
swift package resolve

# Xcode 프로젝트 재생성
rm -rf NotepadNext.xcodeproj
xcodegen generate
```

### 테스트 실패

```bash
# 테스트 캐시 정리
xcodebuild clean -scheme NotepadNextTests

# 특정 테스트만 실행
xcodebuild test -scheme NotepadNextTests \
  -only-testing NotepadNextTests/TextBufferTests/testInsertText

# 테스트 디버깅
xcodebuild test -scheme NotepadNextTests -verbose
```

### 공증 실패

```bash
# 공증 상태 확인
xcrun notarytool info <SUBMISSION_ID> \
  --apple-id $APPLE_ID --password $PASSWORD

# 공증 로그 확인
xcrun notarytool log <SUBMISSION_ID> \
  --apple-id $APPLE_ID --password $PASSWORD

# DMG 다시 서명
codesign --verify --verbose /path/to/file.dmg
```

### GitHub Actions 실패

```bash
# 워크플로우 로그 확인
gh run view <RUN_ID> --log

# 로컬에서 재현
act -l  # 사용 가능한 워크플로우 목록
act -j build  # 특정 job 실행
```

---

## 📊 성능 최적화 팁

### 빌드 시간 단축
```bash
# 병렬 빌드
xcodebuild -parallelizeTargets

# 불필요한 대상 제외
xcodebuild build -scheme NotepadNext  # 테스트 제외

# 증분 빌드 사용
rm -rf build && xcodebuild build -derivedDataPath build
```

### 테스트 속도 개선
```bash
# 병렬 테스트
xcodebuild test -parallel-testing-enabled YES

# 특정 테스트만 실행
xcodebuild test -only-testing "NotepadNextTests/TextBufferTests"

# 테스트 타임아웃 증가
xcodebuild test -timeout 600
```

### 메모리 사용량 최적화
```bash
# 불필요한 캐시 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/

# 큰 파일 컷오프
git gc  # git 저장소 최적화
```

---

## 🔐 보안 체크리스트

### 각 환경 설정 시

```bash
# 1. Secrets 확인
gh secret list

# 2. 필수 Secrets 설정
gh secret set APPLE_ID --body "dev@example.com"
gh secret set APPLE_ID_PASSWORD --body "app-password"
gh secret set APPLE_TEAM_ID --body "ABC123XYZ"
gh secret set APPLE_CERTIFICATE_BASE64 --body "$(cat cert.p12 | base64)"

# 3. 인증서 유효성 확인
security find-certificate -c "Developer ID" -p | openssl x509 -text -noout

# 4. 코드서명 테스트
codesign -v -v "path/to/app"
```

---

## 📈 모니터링

### 빌드 시간 추적
```bash
# 타겟별 빌드 시간
xcodebuild build -scheme NotepadNext -showBuildTimingSummary

# 전체 워크플로우 시간
time xcodebuild build -scheme NotepadNext
```

### 테스트 커버리지
```bash
# 커버리지 리포트 생성
xcodebuild test \
  -scheme NotepadNext \
  -enableCodeCoverage YES \
  -resultBundlePath coverage.xcresult

# 커버리지 분석
xcrun xccov view coverage.xcresult
```

### GitHub Actions 상태
```bash
# 최근 실행 확인
gh run list --limit 10

# 특정 워크플로우 상태
gh workflow view build.yml

# 실패한 작업 확인
gh run list --status failure
```

---

## 🎯 릴리스 체크리스트 (간단)

```bash
# 1. 모든 테스트 통과 확인
xcodebuild test -scheme NotepadNext

# 2. 코드 스타일 확인
swift-format lint -r Sources Tests
swiftlint lint

# 3. 버전 업데이트
./Scripts/version.sh set X.Y.Z

# 4. CHANGELOG 작성
# (CHANGELOG.md 편집)

# 5. 커밋
git add .
git commit -m "chore(release): vX.Y.Z"

# 6. 태그
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# 7. 푸시 (GitHub Actions가 나머지 처리)
git push origin main --tags
```

---

## 🚨 긴급 상황

### 잘못된 태그 삭제
```bash
# 로컬 삭제
git tag -d vX.Y.Z

# 원격 삭제
git push origin --delete vX.Y.Z
```

### 릴리스 롤백
```bash
# GitHub Release 삭제
gh release delete vX.Y.Z

# 이전 버전으로 되돌리기
git revert HEAD

# 또는 리셋 (주의!)
git reset --hard HEAD~1
```

### 긴급 핫픽스
```bash
# main에서 분기
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 수정 및 테스트
# ...

# 빠른 병합
git checkout main
git merge --no-ff hotfix/critical-bug
git tag -a vX.Y.Z-hotfix1
git push origin main --tags
```

---

## 📚 유용한 한 줄 명령어

```bash
# 현재 버전 출력
grep 'let version = ' Sources/NotepadNext/App/Version.swift | sed 's/.*"\(.*\)".*/\1/'

# 마지막 태그 확인
git describe --tags --abbrev=0

# 커밋 수 세기
git rev-list --count HEAD

# 파일 라인 수
find Sources -name "*.swift" | xargs wc -l

# 빌드 크기
du -sh build/Build/Products/Release/NotepadNext.app

# SwiftLint 규칙 개수
swiftlint rules | wc -l

# 의존성 목록
swift package dump-package | jq '.dependencies[].url'

# 테스트 개수
find Tests -name "*.swift" -exec grep -c "func test" {} \; | awk '{s+=$1} END {print s}'
```

---

## 🔗 빠른 링크

### 문서
- [전체 빌드 시스템](NOTEPAD_NEXT_BUILD_SYSTEM.md)
- [초기화 가이드](NOTEPAD_NEXT_SETUP_GUIDE.md)
- [릴리스 자동화](NOTEPAD_NEXT_RELEASE_AUTOMATION.md)
- [고급 CI/CD](NOTEPAD_NEXT_ADVANCED_CICD.md)

### 공식 자료
- [Apple Developer](https://developer.apple.com)
- [Swift Package Manager](https://www.swift.org/package-manager/)
- [GitHub Actions](https://github.com/features/actions)

### 도구
- [SwiftFormat Rules](https://github.com/nicklockwood/SwiftFormat/blob/master/README.md)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/)
- [Tree-Sitter](https://tree-sitter.github.io/tree-sitter/)

---

## 💡 유용한 팁

### Xcode 단축키
- `Cmd + B`: 빌드
- `Cmd + U`: 테스트
- `Cmd + K`: 콘솔 정리
- `Cmd + Shift + K`: 빌드 정리
- `Cmd + Ctrl + E`: 에디터 선택 확장

### 생산성 향상
```bash
# alias 추가 (~/.zshrc 또는 ~/.bash_profile)
alias nb='./Scripts/fast-build.sh'
alias nt='./Scripts/fast-test.sh'
alias nf='swift-format format -r Sources Tests'
alias nl='swiftlint lint'

# 사용
nb          # 빠른 빌드
nt unit     # 단위 테스트
nf          # 포맷팅
nl          # Linting
```

### VS Code 설정 (선택사항)
```json
{
  "swift.sourcekit-lsp.serverPath": "/usr/bin/sourcekit-lsp",
  "swift.linting.configuration": ".swiftlint.yml"
}
```

---

**마지막 업데이트: 2024-04-13**

더 자세한 정보는 각 문서를 참조하세요.
