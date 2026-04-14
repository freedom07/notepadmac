# NotepadNext: 빌드 시스템 및 CI/CD 종합 가이드

## 📋 문서 구조

이 종합 가이드는 4개의 상세 문서로 구성되어 있습니다:

### 1. **NOTEPAD_NEXT_BUILD_SYSTEM.md** (핵심 설계)
프로젝트 아키텍처 및 구축 기초

**주요 내용:**
- Xcode 프로젝트 vs SPM vs Tuist 선택 기준
- 디렉토리 구조 및 모듈 조직
- Package.swift 완전한 구성
- 핵심 의존성 (Tree-Sitter, Sparkle, etc.)
- 테스트 전략 (단위, 성능, 스냅샷, UI)
- GitHub Actions 기본 워크플로우

**언제 읽을까:**
- 프로젝트 초기 설정
- 모듈 구조 이해
- 의존성 관리 정책
- 테스팅 전략 수립

---

### 2. **NOTEPAD_NEXT_SETUP_GUIDE.md** (실행 가이드)
단계별 프로젝트 초기화

**주요 내용:**
- 디렉토리 생성 (한 줄 명령)
- Package.swift 작성
- Xcode 프로젝트 생성
- 코드 스타일 구성 (SwiftFormat, SwiftLint)
- TextBuffer, SearchEngine, Encoding 구현
- GitHub Actions 워크플로우 생성
- 초기 커밋 전략

**언제 읽을까:**
- 실제 프로젝트 시작
- 개발 환경 설정
- 코어 모듈 구현
- CI/CD 초기 구성

**실행 시간:** 약 30분

---

### 3. **NOTEPAD_NEXT_RELEASE_AUTOMATION.md** (배포 자동화)
릴리스 및 배포 프로세스

**주요 내용:**
- Semantic Versioning 구현
- 자동 CHANGELOG 생성
- DMG 빌드 및 서명
- Apple 공증(Notarization) 자동화
- Sparkle Appcast 생성
- GitHub Secrets 관리
- 완전한 릴리스 워크플로우 YAML
- 릴리스 전 체크리스트

**언제 읽을까:**
- 첫 릴리스 준비
- 배포 자동화 구현
- 공증 프로세스 설정
- 사용자 배포 워크플로우

**Key Scripts:**
```bash
./Scripts/version.sh set 1.2.3
./Scripts/build-dmg.sh
./Scripts/notarize-app.sh
./Scripts/generate-changelog.sh
```

---

### 4. **NOTEPAD_NEXT_ADVANCED_CICD.md** (최적화 및 모니터링)
성능, 품질, 모니터링

**주요 내용:**
- 병렬 빌드 및 테스트
- 증분 빌드 캐싱
- 자동 코드 품질 검사
- 성능 모니터링
- 빌드 실패 알림
- 메트릭 대시보드
- 개발자 빠른 빌드 스크립트

**언제 읽을까:**
- 프로젝트 성숙 단계
- 빌드 시간 최적화
- 품질 게이트 구현
- 팀 확대 준비

---

## 🚀 빠른 시작 (5분)

### 1단계: 프로젝트 구조 생성
```bash
mkdir -p NotepadNext
cd NotepadNext

mkdir -p Sources/{NotepadNext,NotepadNextCore,SyntaxHighlighter}
mkdir -p Tests/{NotepadNextTests,UITests,SnapshotTests}
mkdir -p Scripts Resources .github/workflows .github/ISSUE_TEMPLATE

git init
```

### 2단계: Package.swift 생성
`NOTEPAD_NEXT_SETUP_GUIDE.md`의 Package.swift 예제를 복사하여 프로젝트 루트에 저장

### 3단계: Xcode 프로젝트 생성
```bash
# Option 1: xcodegen (권장)
brew install xcodegen
xcodegen generate

# Option 2: Xcode 직접 생성
# Xcode > File > New > Project (macOS App)
```

### 4단계: GitHub Actions 워크플로우
`NOTEPAD_NEXT_SETUP_GUIDE.md`의 워크플로우 YAML 파일들을 `.github/workflows/`에 생성

### 5단계: 초기 커밋
```bash
git add .
git commit -m "Initial commit: project setup"
git branch -M main
```

---

## 📊 아키텍처 개요

```
┌─────────────────────────────────────────────────────┐
│            NotepadNext Application                  │
└────────────────┬────────────────────────────────────┘
                 │
        ┌────────┴──────────┐
        │                   │
    ┌───▼────┐         ┌───▼──────────┐
    │   UI   │         │ Syntax       │
    │        │         │ Highlighter  │
    └───┬────┘         └───┬──────────┘
        │                  │
    ┌───┴──────────────────┴────┐
    │                           │
┌───▼───────────────┐    ┌─────▼──────┐
│ NotepadNextCore   │    │ Tree-       │
│ • TextBuffer      │    │ Sitter     │
│ • SearchEngine    │    │            │
│ • Encoding        │    └────────────┘
└───────────────────┘

Frameworks:
├── AppKit (macOS native UI)
├── Foundation (I/O, encoding, etc.)
├── Logging (structured logging)
└── Testing (XCTest)
```

---

## 🔄 개발 워크플로우

### 일일 개발

```bash
# 1. 기능 브랜치 시작
git checkout develop
git pull origin develop
git checkout -b feature/my-feature

# 2. 빠른 개발 빌드
./Scripts/fast-build.sh

# 3. 코드 스타일 확인
swift-format format -r Sources Tests
swiftlint lint

# 4. 테스트
./Scripts/fast-test.sh unit

# 5. 커밋 및 푸시
git add .
git commit -m "feat(module): description"
git push -u origin feature/my-feature
```

### PR 병합

1. GitHub에서 PR 생성
2. CI/CD 자동 실행:
   - Build 워크플로우 ✓
   - Tests 워크플로우 ✓
   - Code Quality 워크플로우 ✓
3. Code review 요청
4. 승인 후 squash & merge

### 릴리스

```bash
# 1. develop에서 main으로
git checkout main
git pull origin main
git merge --no-ff develop

# 2. 버전 업데이트
./Scripts/version.sh set 1.2.3

# 3. CHANGELOG 작성
# (자동 또는 수동)

# 4. 커밋 및 태그
git add .
git commit -m "chore(release): v1.2.3"
git tag -a v1.2.3 -m "Release v1.2.3"

# 5. 푸시 (GitHub Actions 자동 실행)
git push origin main
git push origin v1.2.3

# GitHub Actions가 자동으로:
# - 빌드 및 테스트
# - DMG 생성 및 서명
# - 공증
# - GitHub Release 생성
# - Appcast 업데이트
```

---

## 📁 핵심 파일 위치

### 구성 파일
```
NotepadNext/
├── Package.swift                          # SPM 의존성
├── NotepadNext.xcodeproj/project.pbxproj # Xcode 프로젝트
├── .swiftformat                           # Code format config
├── .swiftlint.yml                         # Linting rules
└── build.xcconfig                         # Build settings
```

### 스크립트
```
Scripts/
├── fast-build.sh          # 개발 빠른 빌드
├── fast-test.sh           # 개발 빠른 테스트
├── version.sh             # 버전 관리
├── build-dmg.sh           # DMG 생성
├── sign-app.sh            # 코드 서명
├── notarize-app.sh        # Apple 공증
└── generate-changelog.sh  # CHANGELOG 생성
```

### 워크플로우
```
.github/workflows/
├── build.yml              # 기본 빌드
├── test.yml               # 테스트
├── lint.yml               # 코드 스타일
├── release.yml            # 완전한 릴리스
├── code-review.yml        # 자동 리뷰
└── build-metrics.yml      # 성능 추적
```

---

## 🎯 주요 의사결정

### 1. Xcode Project vs SPM
**선택: Xcode + SPM**

| 요소 | 선택 | 이유 |
|------|------|------|
| 빌드 시스템 | Xcode | AppKit UI, 네이티브 코드 서명 |
| 의존성 | SPM | 경량, 내장, 간편 |
| 모듈 | 프레임워크 | 코드 재사용, 테스트 격리 |

### 2. 의존성 정책
**원칙: 최소화**

- ✓ tree-sitter-swift (필수)
- ✓ swift-log (권장)
- ✗ 무거운 프레임워크 제외
- ✗ 과도한 외부 의존 방지

### 3. 테스트 전략
**계층별 테스트**

1. **단위 테스트**: 핵심 로직 (TextBuffer, SearchEngine)
2. **성능 테스트**: 대용량 파일, 검색 속도
3. **스냅샷 테스트**: 구문 강조 출력
4. **UI 테스트**: 에디터 상호작용

### 4. 릴리스 전략
**자동화 + 검증**

- Semantic Versioning 엄격 준수
- 모든 릴리스 자동화
- Apple 공증 필수
- Appcast를 통한 자동 업데이트

---

## 📈 성능 목표

| 메트릭 | 목표 | 현재 |
|--------|------|------|
| 전체 빌드 시간 | < 2분 | - |
| 단위 테스트 | < 30초 | - |
| UI 테스트 | < 2분 | - |
| 대용량 파일 (1MB) | < 100ms | - |
| 검색 (100k 라인) | < 50ms | - |
| 앱 번들 크기 | < 50MB | - |

---

## 🔐 보안 체크리스트

### 코드 서명
- [ ] Apple Developer 계정 설정
- [ ] Developer ID Certificate 생성
- [ ] GitHub Secrets에 인증서 저장

### 공증
- [ ] Apple ID 계정
- [ ] App-specific password 생성
- [ ] Team ID 확보

### 자격증명 관리
- [ ] GitHub Secrets 사용
- [ ] 민감한 정보를 코드에 포함하지 않음
- [ ] 주기적인 보안 감사

---

## 🤝 팀 확대 가이드

### 1단계: 단일 개발자
- 기본 워크플로우 설정
- 로컬 빌드 및 테스트
- 간단한 PR 검토

### 2단계: 작은 팀 (2-3명)
- 코드 스타일 가이드 작성
- 자동 코드 리뷰 추가
- Contributing guidelines 작성

### 3단계: 중간 팀 (4-10명)
- 복잡한 CI/CD 파이프라인
- 성능 모니터링 대시보드
- 자동화된 릴리스 프로세스

### 4단계: 대규모 팀 (10+명)
- 여러 릴리스 라인 관리
- 복잡한 종속성 관리
- 자세한 감사 로그

---

## 🆘 트러블슈팅

### 빌드 실패

```bash
# 캐시 정리
rm -rf build ~/Library/Developer/Xcode/DerivedData/

# 의존성 재설정
rm -rf .build Package.resolved
swift package resolve

# 다시 빌드
xcodebuild clean build -scheme NotepadNext
```

### 테스트 실패

```bash
# 개별 테스트 실행
xcodebuild test \
  -scheme NotepadNextTests \
  -testPlan UnitTests \
  -verbose

# 스냅샷 업데이트
# record flag 사용
```

### 공증 실패

```bash
# 공증 로그 확인
xcrun notarytool log <SUBMISSION_ID> \
  --apple-id $APPLE_ID \
  --password $PASSWORD \
  --team-id $TEAM_ID
```

---

## 📚 추가 자료

### 공식 문서
- [Apple: Notarizing macOS Software](https://developer.apple.com/documentation/notaryapi)
- [Swift Package Manager Guide](https://www.swift.org/package-manager/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

### 커뮤니티 리소스
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Tree-Sitter Documentation](https://tree-sitter.github.io/tree-sitter/)
- [Sparkle Framework](https://sparkle-project.org/)

---

## 🔗 문서 네비게이션

```
README_BUILD_SYSTEM.md (현재 위치)
│
├─→ NOTEPAD_NEXT_BUILD_SYSTEM.md
│   ├─ 프로젝트 아키텍처
│   ├─ 모듈 조직
│   ├─ 의존성 관리
│   └─ 테스트 전략
│
├─→ NOTEPAD_NEXT_SETUP_GUIDE.md
│   ├─ 단계별 초기화
│   ├─ 코어 모듈 구현
│   ├─ 기본 워크플로우
│   └─ 개발 환경 설정
│
├─→ NOTEPAD_NEXT_RELEASE_AUTOMATION.md
│   ├─ 버전 관리
│   ├─ 릴리스 자동화
│   ├─ DMG 및 공증
│   └─ 배포 프로세스
│
└─→ NOTEPAD_NEXT_ADVANCED_CICD.md
    ├─ 빌드 최적화
    ├─ 품질 게이트
    ├─ 성능 모니터링
    └─ 고급 구성
```

---

## 📋 초기 설정 체크리스트

- [ ] 4개 문서 읽음
- [ ] NOTEPAD_NEXT_SETUP_GUIDE.md로 프로젝트 초기화
- [ ] Xcode 프로젝트 생성
- [ ] SwiftFormat/SwiftLint 설정
- [ ] GitHub Actions 워크플로우 생성
- [ ] 첫 번째 PR 병합
- [ ] NOTEPAD_NEXT_RELEASE_AUTOMATION.md로 릴리스 자동화 설정
- [ ] 첫 번째 릴리스 수행
- [ ] 모니터링 대시보드 설정

---

## ✨ 다음 단계

### 즉시 (1주)
1. 프로젝트 초기화 완료
2. 기본 CI/CD 작동 확인
3. 첫 번째 기능 개발

### 단기 (1개월)
1. UI 구현 (AppDelegate, EditorViewController)
2. 구문 강조 통합
3. 플러그인 시스템 초안

### 중기 (3개월)
1. 주요 기능 완성
2. 첫 번째 릴리스 준비
3. 커뮤니티 피드백 수집

### 장기 (6개월+)
1. 정기적인 릴리스
2. 커뮤니티 기여 수락
3. 플러그인 에코시스템 구축

---

**이 가이드는 프로덕션 수준의 macOS 애플리케이션 개발을 위한 완전한 CI/CD 파이프라인을 제공합니다.**

마지막 업데이트: 2024-04-13
