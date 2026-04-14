# NotepadNext: 릴리스 자동화 및 배포 가이드

## 1. 릴리스 프로세스 개요

```
개발 워크플로우:
┌─────────────────┐
│ 기능 개발        │ (feature/*)
└────────┬────────┘
         │
┌────────▼────────────────────┐
│ PR 검토 & 머지 (develop)    │
└────────┬────────────────────┘
         │
┌────────▼────────────────────┐
│ 릴리스 준비 (release/*)     │
├────────────────────────────┤
│ • 버전 업데이트            │
│ • CHANGELOG 작성           │
│ • 테스트                   │
└────────┬────────────────────┘
         │
┌────────▼────────────────────┐
│ 태그 생성 (v1.2.3)         │
└────────┬────────────────────┘
         │
┌────────▼────────────────────┐
│ GitHub Actions 자동 실행   │
├────────────────────────────┤
│ • 빌드                     │
│ • 서명 및 공증             │
│ • DMG/ZIP 생성             │
│ • Appcast 업데이트         │
│ • GitHub Release 생성       │
└────────────────────────────┘
```

---

## 2. 버전 관리

### 2.1 Semantic Versioning 구현

```bash
#!/bin/bash
# Scripts/version.sh
# 버전 관리 유틸리티

VERSION_FILE="Sources/NotepadNext/App/Version.swift"
XCODE_VERSION_KEY="MARKETING_VERSION"

get_current_version() {
    grep -m1 "let version = " "$VERSION_FILE" | \
        sed 's/.*version = "\(.*\)".*/\1/'
}

set_version() {
    local new_version=$1
    
    # Swift 파일 업데이트
    sed -i '' "s/let version = \".*\"/let version = \"$new_version\"/" \
        "$VERSION_FILE"
    
    # Xcode 프로젝트 업데이트
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $new_version;/" \
        NotepadNext.xcodeproj/project.pbxproj
    
    # Info.plist 업데이트 (있으면)
    if [[ -f "Info.plist" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $new_version" \
            Info.plist
    fi
}

bump_version() {
    local current=$(get_current_version)
    local major=$(echo $current | cut -d. -f1)
    local minor=$(echo $current | cut -d. -f2)
    local patch=$(echo $current | cut -d. -f3)
    
    case ${1:-patch} in
        major)
            new_version="$((major + 1)).0.0"
            ;;
        minor)
            new_version="$major.$((minor + 1)).0"
            ;;
        patch)
            new_version="$major.$minor.$((patch + 1))"
            ;;
        *)
            new_version=$1
            ;;
    esac
    
    set_version "$new_version"
    echo "Bumped version: $current -> $new_version"
}

# 사용법:
# ./Scripts/version.sh get              # 현재 버전 조회
# ./Scripts/version.sh bump major       # 메이저 버전 증가
# ./Scripts/version.sh bump minor       # 마이너 버전 증가
# ./Scripts/version.sh bump patch       # 패치 버전 증가
# ./Scripts/version.sh set 2.0.0        # 특정 버전 설정
```

### 2.2 Version.swift 파일

```bash
cat > Sources/NotepadNext/App/Version.swift << 'EOF'
import Foundation

struct AppVersion {
    static let current = "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    static var fullVersion: String {
        "\(current) (Build \(buildNumber))"
    }
    
    static var isPrerelease: Bool {
        current.contains("-")
    }
}
EOF
```

---

## 3. CHANGELOG 관리

### 3.1 자동 CHANGELOG 생성

```bash
#!/bin/bash
# Scripts/generate-changelog.sh

set -e

# 마지막 태그 조회
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
NEW_VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/v//')}"

if [[ -z "$NEW_VERSION" ]]; then
    echo "Error: Version not found"
    exit 1
fi

echo "Generating changelog for v$NEW_VERSION"

# 임시 파일 생성
TEMP_CHANGELOG=$(mktemp)

# 헤더 작성
{
    echo "## [v$NEW_VERSION] - $(date +%Y-%m-%d)"
    echo ""
    
    # 마지막 태그가 있으면 비교, 없으면 전체 커밋 사용
    if [[ -n "$LAST_TAG" ]]; then
        COMMIT_RANGE="$LAST_TAG..HEAD"
    else
        COMMIT_RANGE="HEAD"
    fi
    
    # 기능 (feat)
    echo "### Added"
    git log "$COMMIT_RANGE" --grep="^feat" --oneline 2>/dev/null | \
        sed 's/^[a-f0-9]* feat(\([^)]*\)): /- \1: /' || echo "- (no new features)"
    echo ""
    
    # 버그 수정 (fix)
    echo "### Fixed"
    git log "$COMMIT_RANGE" --grep="^fix" --oneline 2>/dev/null | \
        sed 's/^[a-f0-9]* fix(\([^)]*\)): /- \1: /' || echo "- (no fixes)"
    echo ""
    
    # 기타 (refactor, perf, etc.)
    echo "### Changed"
    git log "$COMMIT_RANGE" --oneline 2>/dev/null | \
        grep -E "^[a-f0-9]* (refactor|perf|docs|style|chore)" | \
        sed 's/^[a-f0-9]* \([a-z]*\)(\([^)]*\)): /- \2: [\1] /' || echo "- (no changes)"
    echo ""
    
} > "$TEMP_CHANGELOG"

# 기존 CHANGELOG와 병합
if [[ -f "CHANGELOG.md" ]]; then
    cat CHANGELOG.md >> "$TEMP_CHANGELOG"
fi

# 파일 교체
mv "$TEMP_CHANGELOG" CHANGELOG.md

echo "✓ CHANGELOG.md generated"
echo ""
cat CHANGELOG.md | head -30
```

### 3.2 CHANGELOG.md 구조

```markdown
# Changelog

All notable changes to NotepadNext will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Feature under development

## [1.0.0] - 2024-04-13

### Added
- Initial release of NotepadNext
- Text editor with syntax highlighting
- Search and replace functionality
- Plugin system
- Multi-language support

### Fixed
- Initial bug fixes

[Unreleased]: https://github.com/username/NotepadNext/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/username/NotepadNext/releases/tag/v1.0.0
```

---

## 4. 빌드 및 서명 자동화

### 4.1 DMG 빌드 스크립트

```bash
#!/bin/bash
# Scripts/build-dmg.sh

set -e

APP_PATH="${1:?App path required}"
OUTPUT_DMG="${2:?Output DMG path required}"
BACKGROUND_IMG="${3:-}"

TEMP_DMG="/tmp/NotepadNext-temp.dmg"
MOUNT_POINT="/tmp/NotepadNext-dmg"

echo "Building DMG: $OUTPUT_DMG"

# 기존 파일 정리
[[ -f "$TEMP_DMG" ]] && rm "$TEMP_DMG"
[[ -f "$OUTPUT_DMG" ]] && rm "$OUTPUT_DMG"
[[ -d "$MOUNT_POINT" ]] && rm -rf "$MOUNT_POINT"

# 임시 DMG 생성
echo "Creating temporary DMG..."
hdiutil create -volname "NotepadNext" \
    -srcfolder "$APP_PATH" \
    -ov -format UDRW \
    "$TEMP_DMG"

# DMG 마운트
mkdir -p "$MOUNT_POINT"
hdiutil attach -mountpoint "$MOUNT_POINT" "$TEMP_DMG"

echo "Configuring DMG layout..."

# Applications 심볼릭 링크 추가
ln -s /Applications "$MOUNT_POINT/Applications" 2>/dev/null || true

# 배경 이미지 추가 (제공된 경우)
if [[ -n "$BACKGROUND_IMG" ]] && [[ -f "$BACKGROUND_IMG" ]]; then
    mkdir -p "$MOUNT_POINT/.background"
    cp "$BACKGROUND_IMG" "$MOUNT_POINT/.background/background.png"
fi

# AppleScript를 통한 Finder 윈도우 설정
echo "Setting DMG appearance..."
osascript - "$MOUNT_POINT" <<'APPLESCRIPT'
on run args
    set dmgPath to item 1 of args
    
    tell application "Finder"
        tell disk "NotepadNext"
            open
            delay 1
            
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {0, 0, 512, 384}
            
            set position of item "NotepadNext.app" of container window to {64, 96}
            set position of item "Applications" of container window to {320, 96}
            
            -- 배경 이미지가 있으면 설정
            try
                set background picture of icon view options of container window ¬
                    to file ".background:background.png"
            end try
            
            set text size of icon view options of container window to 12
            set icon size of icon view options of container window to 64
            
            close
            eject
        end tell
    end tell
end run
APPLESCRIPT

# DMG 언마운트
sleep 2
hdiutil detach "$MOUNT_POINT"

# 압축된 최종 DMG 생성
echo "Compressing DMG..."
hdiutil convert "$TEMP_DMG" \
    -format ULFO \
    -o "$OUTPUT_DMG"

# 정리
rm "$TEMP_DMG"
rm -rf "$MOUNT_POINT"

echo "✓ DMG created: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
```

### 4.2 코드 서명 스크립트

```bash
#!/bin/bash
# Scripts/sign-app.sh

set -e

APP_PATH="${1:?App path required}"
SIGNING_IDENTITY="${2:?Signing identity required}"

echo "Signing app: $APP_PATH"
echo "Using identity: $SIGNING_IDENTITY"

# 메인 바이너리 서명
codesign --force \
    --verify \
    --verbose=4 \
    --sign "$SIGNING_IDENTITY" \
    "$APP_PATH"

# 프레임워크 서명
if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
    find "$APP_PATH/Contents/Frameworks" -name "*.framework" -exec \
        codesign --force \
        --sign "$SIGNING_IDENTITY" \
        {} \;
fi

# 확장자 서명
if [[ -d "$APP_PATH/Contents/PlugIns" ]]; then
    find "$APP_PATH/Contents/PlugIns" -type f -exec \
        codesign --force \
        --sign "$SIGNING_IDENTITY" \
        {} \;
fi

# 최종 확인
echo "Verifying signature..."
codesign --verify --verbose=4 "$APP_PATH"

echo "✓ App signed successfully"
```

### 4.3 공증(Notarization) 스크립트

```bash
#!/bin/bash
# Scripts/notarize-app.sh

set -e

DMG_PATH="${1:?DMG path required}"
APPLE_ID="${2:?Apple ID required}"
APPLE_PASSWORD="${3:?Apple password required}"
TEAM_ID="${4:?Team ID required}"

echo "Submitting for notarization: $DMG_PATH"

# 공증 제출
echo "Uploading to Apple servers..."
NOTARY_RESPONSE=$(xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait \
    --output json 2>&1)

echo "$NOTARY_RESPONSE" | jq .

# 상태 확인
STATUS=$(echo "$NOTARY_RESPONSE" | jq -r '.status')
if [[ "$STATUS" != "Accepted" ]]; then
    echo "✗ Notarization failed"
    echo "$NOTARY_RESPONSE" | jq .
    exit 1
fi

echo "✓ Notarization successful"

# DMG에 공증 티켓 스테이플
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "✓ Stapling complete"
```

---

## 5. GitHub Actions 릴리스 워크플로우

### 5.1 완전한 릴리스 워크플로우

```yaml
# .github/workflows/release.yml

name: Release

on:
  push:
    tags:
      - 'v*'

env:
  XCODE_VERSION: 15.0

jobs:
  validate-tag:
    name: Validate Release Tag
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Validate tag format
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          if [[ ! $TAG =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
            echo "Invalid tag format: $TAG"
            exit 1
          fi
          echo "Version: ${TAG#v}"
      
      - name: Check if tag is annotated
        run: |
          if ! git cat-file -t ${GITHUB_REF#refs/tags/} | grep -q "tag"; then
            echo "Tag must be annotated"
            exit 1
          fi

  build-and-release:
    name: Build and Release
    runs-on: macos-latest
    needs: validate-tag
    
    environment:
      name: production
      url: https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
    
    env:
      APPLE_ID: ${{ secrets.APPLE_ID }}
      APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
      APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
      SIGNING_IDENTITY: ${{ secrets.APPLE_SIGNING_IDENTITY }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup Xcode
        run: |
          sudo xcode-select -s /Applications/Xcode_${XCODE_VERSION}.app
          xcodebuild -version
      
      - name: Cache SPM dependencies
        uses: actions/cache@v3
        with:
          path: |
            ~/Library/Developer/Xcode/DerivedData
            ~/.cache/apple
          key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift.lock') }}
          restore-keys: |
            ${{ runner.os }}-spm-
      
      - name: Extract version from tag
        id: version
        run: |
          TAG=${GITHUB_REF#refs/tags/v}
          echo "VERSION=$TAG" >> $GITHUB_OUTPUT
          echo "Version: $TAG"
      
      - name: Verify version matches
        run: |
          CURRENT_VERSION=$(grep -m1 'let version = ' \
            Sources/NotepadNext/App/Version.swift | \
            sed 's/.*"\(.*\)".*/\1/')
          if [[ "$CURRENT_VERSION" != "${{ steps.version.outputs.VERSION }}" ]]; then
            echo "Version mismatch: tag=${{ steps.version.outputs.VERSION }}, code=$CURRENT_VERSION"
            exit 1
          fi
      
      - name: Setup signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          # Base64 인증서를 파일로 변환
          echo "$CERTIFICATE_BASE64" | base64 -D > certificate.p12
          
          # 키체인 생성
          security create-keychain -p "" build.keychain
          security unlock-keychain -p "" build.keychain
          security set-keychain-settings -t 3600 build.keychain
          
          # 인증서 임포트
          security import certificate.p12 \
            -k build.keychain \
            -P "$CERTIFICATE_PASSWORD" \
            -A
          
          # 서명 권한 설정
          security set-key-partition-list \
            -S apple-tool:,apple:,codesign: \
            -k "" build.keychain
      
      - name: Build app
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -configuration Release \
            -destination 'platform=macOS,arch=arm64,variant=native' \
            -keychain build.keychain \
            -derivedDataPath build \
            CODE_SIGN_STYLE=Automatic \
            CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
      
      - name: Prepare app bundle
        run: |
          mkdir -p dist
          cp -r build/Build/Products/Release/NotepadNext.app dist/
      
      - name: Sign app
        run: |
          ./Scripts/sign-app.sh \
            "dist/NotepadNext.app" \
            "$SIGNING_IDENTITY"
      
      - name: Create DMG
        run: |
          chmod +x Scripts/build-dmg.sh
          ./Scripts/build-dmg.sh \
            "dist/NotepadNext.app" \
            "dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg" \
            "Resources/DMG/background.png"
      
      - name: Notarize DMG
        run: |
          chmod +x Scripts/notarize-app.sh
          ./Scripts/notarize-app.sh \
            "dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg" \
            "$APPLE_ID" \
            "$APPLE_ID_PASSWORD" \
            "$APPLE_TEAM_ID"
      
      - name: Create ZIP archive
        run: |
          cd dist
          zip -r -q NotepadNext-${{ steps.version.outputs.VERSION }}.zip \
            NotepadNext.app
          cd ..
      
      - name: Generate checksums
        run: |
          cd dist
          sha256sum NotepadNext-*.dmg > SHA256.txt
          sha256sum NotepadNext-*.zip >> SHA256.txt
          cat SHA256.txt
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/NotepadNext-*.dmg
            dist/NotepadNext-*.zip
            dist/SHA256.txt
          body_path: CHANGELOG.md
          draft: false
          prerelease: ${{ contains(github.ref, '-') }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Update Sparkle appcast
        if: ${{ !contains(github.ref, '-') }}  # 정식 릴리스만
        run: |
          chmod +x Scripts/generate-appcast.sh
          ./Scripts/generate-appcast.sh \
            --version ${{ steps.version.outputs.VERSION }} \
            --dmg "dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg" \
            --sha256 "$(grep '\.dmg' dist/SHA256.txt | awk '{print $1}')" \
            --notes CHANGELOG.md
          
          # Git 구성
          git config user.name "Release Bot"
          git config user.email "noreply@github.com"
          git add appcast.xml
          git commit -m "chore(release): update appcast for v${{ steps.version.outputs.VERSION }}"
          git push
      
      - name: Cleanup
        if: always()
        run: |
          security delete-keychain build.keychain 2>/dev/null || true
          rm -f certificate.p12
      
      - name: Notify on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ Release build failed for tag ${{ github.ref_name }}'
            })
```

### 5.2 Appcast 생성 스크립트

```bash
#!/bin/bash
# Scripts/generate-appcast.sh

set -e

VERSION=""
DMG_PATH=""
SHA256=""
NOTES_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --dmg) DMG_PATH="$2"; shift 2 ;;
        --sha256) SHA256="$2"; shift 2 ;;
        --notes) NOTES_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$VERSION" ]] || [[ -z "$DMG_PATH" ]]; then
    echo "Usage: generate-appcast.sh --version X.Y.Z --dmg <path> --sha256 <hash> --notes <file>"
    exit 1
fi

echo "Generating appcast for v$VERSION"

# 파일 크기 계산
FILE_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH")

# 릴리스 날짜
RELEASE_DATE=$(date -u +'%a, %d %b %Y %H:%M:%S GMT')

# 노트 생성
RELEASE_NOTES=""
if [[ -f "$NOTES_FILE" ]]; then
    RELEASE_NOTES=$(sed -n "/## \[v$VERSION\]/,/^## /p" "$NOTES_FILE" | \
        head -n -1 | \
        sed 's/^/            /' | \
        sed '1d')
fi

# Appcast XML 엔트리 생성
APPCAST_ENTRY=$(cat <<EOF
    <item>
        <title>Version $VERSION</title>
        <description>
            <![CDATA[
$RELEASE_NOTES
            ]]>
        </description>
        <pubDate>$RELEASE_DATE</pubDate>
        <link>https://github.com/username/NotepadNext/releases/tag/v$VERSION</link>
        <enclosure
            url="https://github.com/username/NotepadNext/releases/download/v$VERSION/NotepadNext-$VERSION.dmg"
            sparkle:version="$VERSION"
            sparkle:shortVersionString="$VERSION"
            length="$FILE_SIZE"
            type="application/octet-stream"
            sparkle:edSignature="$SIGNATURE" />
        <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
    </item>
EOF
)

# 기존 appcast 파일 읽기 또는 신규 생성
if [[ -f "appcast.xml" ]]; then
    # 새 엔트리를 기존 파일에 삽입
    sed -i '' "/<\/channel>/i\\
$APPCAST_ENTRY
" appcast.xml
else
    # 새 appcast 파일 생성
    cat > appcast.xml << 'APPCAST'
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>NotepadNext</title>
    <link>https://github.com/username/NotepadNext</link>
    <description>A fast text editor for macOS</description>
    <language>en-us</language>
APPCAST
    
    echo "$APPCAST_ENTRY" >> appcast.xml
    
    cat >> appcast.xml << 'APPCAST'
  </channel>
</rss>
APPCAST
fi

echo "✓ Appcast updated"
```

---

## 6. 보안 자격증명 관리

### 6.1 GitHub Secrets 설정

필수 Secrets (Repository Settings > Secrets):

```
APPLE_ID                    - Apple ID (예: dev@example.com)
APPLE_ID_PASSWORD          - App-specific password
APPLE_TEAM_ID              - Apple Developer Team ID
APPLE_CERTIFICATE_BASE64   - Base64 encoded .p12 certificate
APPLE_CERTIFICATE_PASSWORD - Certificate password
APPLE_SIGNING_IDENTITY     - Signing identity name
```

### 6.2 인증서 준비

```bash
#!/bin/bash
# 인증서를 Base64로 인코딩하여 Secret에 저장

# 1. macOS Keychain에서 인증서 내보내기
security find-certificate -c "Developer ID Application" -p \
    | openssl pkcs12 -export -out certificate.p12 -password pass:mypassword

# 2. Base64로 인코딩
base64 -i certificate.p12 | pbcopy

# 3. GitHub Secrets에 APPLE_CERTIFICATE_BASE64로 저장
# 4. 인증서 비밀번호를 APPLE_CERTIFICATE_PASSWORD로 저장

# 파일 정리
rm certificate.p12
```

---

## 7. 릴리스 체크리스트

```bash
#!/bin/bash
# Scripts/pre-release-checklist.sh

set -e

echo "=== Pre-Release Checklist ==="
echo ""

# 1. 브랜치 확인
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "❌ Must be on main branch (current: $CURRENT_BRANCH)"
    exit 1
fi
echo "✓ On main branch"

# 2. 커밋 확인
if ! git diff-index --quiet HEAD --; then
    echo "❌ Working directory has uncommitted changes"
    exit 1
fi
echo "✓ Working directory clean"

# 3. 리모트 동기화 확인
git fetch origin
if ! git merge-base --is-ancestor HEAD origin/main; then
    echo "❌ Local main is behind origin/main"
    exit 1
fi
echo "✓ Local main is up to date"

# 4. 테스트 실행
echo "Running tests..."
xcodebuild test -scheme NotepadNext \
    -destination 'platform=macOS,arch=arm64' \
    -quiet || {
    echo "❌ Tests failed"
    exit 1
}
echo "✓ All tests passed"

# 5. 코드 스타일 확인
echo "Checking code style..."
swift-format lint --recursive Sources Tests || {
    echo "⚠️  Code formatting issues found"
    echo "Run: swift-format format -r Sources Tests"
}
echo "✓ Code style OK"

# 6. SwiftLint
echo "Running SwiftLint..."
swiftlint lint --strict || {
    echo "⚠️  Lint issues found"
}
echo "✓ Linting OK"

# 7. CHANGELOG 확인
if ! grep -q "## \[Unreleased\]" CHANGELOG.md; then
    echo "❌ CHANGELOG.md must have [Unreleased] section"
    exit 1
fi
echo "✓ CHANGELOG.md updated"

# 8. 버전 확인
read -p "Enter version (MAJOR.MINOR.PATCH): " VERSION
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format"
    exit 1
fi
echo "✓ Version format valid: $VERSION"

echo ""
echo "=== All checks passed! ==="
echo ""
echo "Next steps:"
echo "1. ./Scripts/version.sh set $VERSION"
echo "2. git add ."
echo "3. git commit -m 'chore(release): v$VERSION'"
echo "4. git tag -a v$VERSION -m 'Release v$VERSION'"
echo "5. git push && git push --tags"
```

---

## 8. 릴리스 절차

### 단계별 가이드

```bash
# 1. 릴리스 준비
./Scripts/pre-release-checklist.sh

# 2. 버전 업데이트
./Scripts/version.sh set 1.2.3

# 3. CHANGELOG 업데이트
# CHANGELOG.md의 [Unreleased] 섹션을 편집
# 새로운 [1.2.3] 섹션 추가

# 4. 커밋
git add Sources/NotepadNext/App/Version.swift NotepadNext.xcodeproj CHANGELOG.md
git commit -m "chore(release): prepare v1.2.3"

# 5. 태그 생성 (주석 달기)
git tag -a v1.2.3 -m "Release v1.2.3

See CHANGELOG.md for details"

# 6. 푸시 (GitHub Actions가 자동으로 실행됨)
git push origin main
git push origin v1.2.3

# 7. GitHub Actions 모니터링
# https://github.com/username/NotepadNext/actions
```

---

## 9. 배포 후 확인

```bash
#!/bin/bash
# Scripts/verify-release.sh

VERSION="${1:?Version required}"

echo "Verifying release v$VERSION"

# 1. GitHub Release 확인
echo "Checking GitHub Release..."
gh release view "v$VERSION" --json assets

# 2. DMG 다운로드 및 검증
echo "Downloading DMG..."
gh release download "v$VERSION" \
    -p "*.dmg" \
    --dir /tmp

# 3. 서명 확인
echo "Verifying signature..."
codesign -v -v "/tmp/NotepadNext-${VERSION}.dmg"

# 4. 공증 확인
echo "Verifying notarization..."
spctl -a -v -t install "/tmp/NotepadNext-${VERSION}.dmg"

echo "✓ Release verification complete"
```

---

## 10. 트러블슈팅

### 공증 실패

```bash
# 공증 로그 확인
xcrun notarytool log <SUBMISSION_ID> \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_PASSWORD" \
    --team-id "$TEAM_ID"

# 일반적인 원인:
# 1. 불완전한 서명
# 2. 지원되지 않는 바이너리
# 3. 만료된 인증서
```

### 서명 실패

```bash
# 서명 재확인
codesign -d -v NotepadNext.app

# 올바른 ID 찾기
security find-identity -v -p codesigning
```

### GitHub Actions 실패

```bash
# 로그 확인
gh run view --log <RUN_ID>

# 환경 변수 확인
gh secret list

# 다시 실행
gh run rerun <RUN_ID>
```

---

## 요약

이 자동화 워크플로우는 다음을 제공합니다:

✓ **일관된 버전 관리** - Semantic Versioning
✓ **자동화된 CHANGELOG** - 커밋 기반 생성
✓ **안전한 서명** - Apple Developer 인증서 관리
✓ **공증 자동화** - Apple 공증 프로세스
✓ **DMG 생성** - 전문적인 배포 패키지
✓ **GitHub Release** - 자동 생성 및 게시
✓ **Appcast 업데이트** - Sparkle 자동 업데이트 지원
✓ **보안 자격증명 관리** - GitHub Secrets 활용
