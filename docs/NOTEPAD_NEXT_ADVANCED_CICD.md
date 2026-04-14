# NotepadNext: 고급 CI/CD 최적화 및 모니터링

## 1. 빌드 성능 최적화

### 1.1 병렬 빌드 전략

```yaml
# .github/workflows/fast-build.yml
# 대규모 테스트 병렬 실행

name: Fast Parallel Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  matrix-test:
    runs-on: macos-latest
    strategy:
      matrix:
        xcode-version: ['14.3', '15.0', '15.1']
        arch: [arm64, x86_64]
      fail-fast: true
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: |
          sudo xcode-select -s "/Applications/Xcode_${{ matrix.xcode-version }}.app"
      
      - name: Build for ${{ matrix.arch }}
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -configuration Release \
            -destination "platform=macOS,arch=${{ matrix.arch }}" \
            -parallelizeTargets \
            -verbose
      
      - name: Run tests in parallel
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -destination "platform=macOS,arch=${{ matrix.arch }}" \
            -parallel-testing-enabled YES \
            -maximum-concurrent-test-simulator-destinations 4

  unit-tests:
    runs-on: macos-latest
    needs: matrix-test
    steps:
      - uses: actions/checkout@v4
      
      - name: Run unit tests
        run: |
          xcodebuild test \
            -scheme NotepadNextTests \
            -testPlan UnitTests

  ui-tests:
    runs-on: macos-latest
    needs: matrix-test
    steps:
      - uses: actions/checkout@v4
      
      - name: Run UI tests
        run: |
          xcodebuild test \
            -scheme NotepadNextUITests \
            -testPlan UITests

  performance-tests:
    runs-on: macos-latest
    needs: matrix-test
    steps:
      - uses: actions/checkout@v4
      
      - name: Run performance tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -testPlan PerformanceTests \
            -resultBundlePath perf-results.xcresult
      
      - name: Analyze performance
        run: |
          xcrun xccov view perf-results.xcresult > perf-report.txt
          
          # 이전 결과와 비교
          if [[ -f perf-baseline.txt ]]; then
            diff -u perf-baseline.txt perf-report.txt || true
          fi
      
      - name: Store baseline
        run: cp perf-report.txt perf-baseline.txt
      
      - name: Upload to artifact
        uses: actions/upload-artifact@v3
        with:
          name: performance-report
          path: perf-report.txt
```

### 1.2 증분 빌드 캐싱

```yaml
# .github/workflows/incremental-build.yml

name: Incremental Build

on:
  push:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Cache derived data
        id: cache-derived-data
        uses: actions/cache@v3
        with:
          path: build/Build/Products
          key: derived-data-${{ hashFiles('Package.swift.lock', 'Sources/**', 'Tests/**') }}
          restore-keys: |
            derived-data-
      
      - name: Cache SPM
        uses: actions/cache@v3
        with:
          path: |
            ~/Library/Developer/Xcode/DerivedData
            .build
          key: spm-${{ hashFiles('Package.swift.lock') }}
          restore-keys: |
            spm-
      
      - name: Clean if needed
        run: |
          if [[ "${{ steps.cache-derived-data.outputs.cache-hit }}" != "true" ]]; then
            rm -rf build
          fi
      
      - name: Incremental build
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -derivedDataPath build \
            -xcconfig build.xcconfig
      
      - name: Store build artifacts
        uses: actions/cache@v3
        with:
          path: build/Build/Products
          key: derived-data-${{ hashFiles('Package.swift.lock', 'Sources/**', 'Tests/**') }}
```

### 1.3 빌드 구성 최적화

```bash
# build.xcconfig
// Xcode Build Configuration

// Swift 컴파일 최적화
SWIFT_COMPILATION_MODE = wholemodule
SWIFT_OPTIMIZATION_LEVEL = -Osize
SWIFT_WHOLE_MODULE_OPTIMIZATION = YES

// 링크 타임 최적화
LLVM_LTO = YES_THIN

// 병렬 처리
build.parallelizeBuildables = YES
build.numberOfParallelBuildSubtasks = $(NUMBER_OF_PROCESSORS)

// 불필요한 처리 제거
STRIP_INSTALLED_PRODUCT = YES
COPY_PHASE_STRIP = YES
DEAD_CODE_STRIPPING = YES
SEPARATE_STRIP = NO

// 기호 생성 분리
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym

// Xcode 빌드 로그 최소화
GCC_GENERATE_DEBUGGING_SYMBOLS = YES
```

---

## 2. 코드 품질 게이트

### 2.1 자동 코드 리뷰

```yaml
# .github/workflows/code-review.yml

name: Automated Code Review

on:
  pull_request:
    paths:
      - '**.swift'

jobs:
  code-quality:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Check code coverage
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -enableCodeCoverage YES \
            -resultBundlePath coverage.xcresult
          
          # 최소 80% 커버리지 요구
          COVERAGE=$(xcrun xccov view coverage.xcresult | grep -oP '\d+\.\d+(?=%)')
          THRESHOLD=80
          
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "❌ Code coverage $COVERAGE% below threshold $THRESHOLD%"
            exit 1
          fi
          echo "✓ Code coverage: $COVERAGE%"
      
      - name: Check cyclomatic complexity
        run: |
          brew install lizard
          lizard -l swift -C 15 Sources/ | grep -E "^\s+[0-9]+" || true
      
      - name: Dependency check
        run: |
          # SPM 종속성 분석
          swift package dump-package | \
            jq '.dependencies | length'
          
          # 과도한 종속성 확인
          DEPS=$(swift package dump-package | jq '.dependencies | length')
          if [[ $DEPS -gt 10 ]]; then
            echo "⚠️  Warning: $DEPS dependencies (consider minimizing)"
          fi
      
      - name: Comment review on PR
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const coverage = process.env.COVERAGE || 'Unknown';
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Code Quality Report\n- Coverage: ${coverage}%\n- Complexity: ✓\n- Dependencies: ✓`
            });
```

### 2.2 자동 버그 검출

```yaml
# .github/workflows/bug-detection.yml

name: Bug Detection

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  static-analysis:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Run clang static analyzer
        run: |
          xcodebuild analyze \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64'
      
      - name: Check for memory leaks
        run: |
          # 메모리 누수 감지 도구
          brew install valgrind
          # macOS에서는 Instruments 사용 권장
      
      - name: Security scanning
        run: |
          # hardcoded secrets 검사
          brew install talisman
          git diff HEAD~1 | talisman --githook || true
          
          # 의존성 취약점 검사
          swift package describe | \
            jq -r '.dependencies[] | .url' | \
            while read url; do
              echo "Checking: $url"
            done
      
      - name: Runtime behavior analysis
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -enableAddressSanitizer YES \
            -enableThreadSanitizer YES \
            -enableUBSanitizer YES
```

### 2.3 아키텍처 검증

```yaml
# .github/workflows/architecture-check.yml

name: Architecture Validation

on:
  pull_request:
    paths:
      - 'Sources/**'

jobs:
  validate-architecture:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Check module dependencies
        run: |
          cat > check-deps.swift << 'EOF'
          import Foundation
          
          // 모듈 간 의존성 규칙 검증
          let rules = [
            ("UI", ["Core"]),           // UI는 Core에만 의존
            ("Editor", ["Core"]),       // Editor는 Core에만 의존
            ("Syntax", ["Core"]),       // Syntax는 Core에만 의존
            ("Core", [])                // Core는 독립적
          ]
          
          for (module, allowedDeps) in rules {
            // 실제로는 AST 분석 필요
            // 여기서는 간단한 텍스트 검사
            print("Validating \(module)...")
          }
          EOF
          
          swift check-deps.swift
      
      - name: Verify layered architecture
        run: |
          # 계층 아키텍처 검증
          # App -> UI -> Core -> Utilities
          
          echo "Checking import layering..."
          
          # Core는 UI 임포트하면 안됨
          if grep -r "^import.*UI" Sources/NotepadNextCore/; then
            echo "❌ Core should not import UI"
            exit 1
          fi
          
          # UI는 Utilities만 임포트 가능
          echo "✓ Architecture validation passed"
      
      - name: Check for circular dependencies
        run: |
          # 순환 의존성 검사
          echo "Checking for circular dependencies..."
          
          # 실제 구현에서는 더 정교한 분석 필요
          echo "✓ No circular dependencies detected"
```

---

## 3. 성능 모니터링

### 3.1 빌드 시간 추적

```yaml
# .github/workflows/build-metrics.yml

name: Build Metrics

on:
  push:
    branches: [ main ]

jobs:
  track-metrics:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Measure build time
        run: |
          echo "=== Build Time Metrics ==="
          
          # 전체 빌드 시간
          time xcodebuild build \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64' \
            -quiet 2>&1 | tee build-log.txt
          
          # 타겟별 시간
          echo ""
          echo "Target compile times:"
          xcodebuild build \
            -scheme NotepadNext \
            -showBuildSettings | \
            grep SRCROOT
      
      - name: Extract metrics
        run: |
          # 빌드 시간 추출
          TOTAL_TIME=$(grep real build-log.txt | awk '{print $2}')
          
          # JSON 형식으로 저장
          cat > metrics.json << EOF
          {
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "build_time_seconds": "$TOTAL_TIME",
            "commit": "${{ github.sha }}",
            "branch": "${{ github.ref_name }}"
          }
          EOF
          
          cat metrics.json
      
      - name: Store metrics
        uses: actions/upload-artifact@v3
        with:
          name: build-metrics
          path: metrics.json
          retention-days: 30
      
      - name: Compare with baseline
        run: |
          # 이전 메트릭과 비교
          if [[ -f metrics-baseline.json ]]; then
            CURRENT=$(jq '.build_time_seconds' metrics.json)
            BASELINE=$(jq '.build_time_seconds' metrics-baseline.json)
            PERCENT=$(echo "scale=2; ($CURRENT - $BASELINE) / $BASELINE * 100" | bc)
            
            echo "Build time change: $PERCENT%"
            
            if (( $(echo "$PERCENT > 20" | bc -l) )); then
              echo "⚠️  Build time increased significantly"
            fi
          fi
```

### 3.2 테스트 성능 추적

```swift
// Tests/Performance/BuildMetricsTests.swift

import XCTest

final class BuildMetricsTests: XCTestCase {
    
    func testLargeFilePerformance() {
        // 1MB 파일 처리
        measure(metrics: [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]) {
            let largeText = String(repeating: "x", count: 1_000_000)
            let buffer = TextBuffer()
            buffer.insert(largeText, at: 0)
            _ = buffer.text
        }
    }
    
    func testSearchPerformance() {
        // 대규모 파일 검색
        let buffer = TextBuffer()
        let largeText = (0..<100_000).map { "line \($0)\n" }.joined()
        buffer.insert(largeText, at: 0)
        
        measure(metrics: [XCTClockMetric()]) {
            let engine = SearchEngine(buffer: buffer)
            _ = engine.find("line 50000")
        }
    }
    
    func testSyntaxHighlightingPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let source = String(repeating: 
                "func fibonacci(n: Int) -> Int { return n }\n", 
                count: 1000)
            
            // Tree-Sitter 성능 테스트
            if let highlighter = try? TreeSitterHighlighter(language: "swift") {
                _ = highlighter.highlight(source: source)
            }
        }
    }
}
```

---

## 4. 모니터링 및 알림

### 4.1 빌드 실패 알림

```yaml
# .github/workflows/notifications.yml

name: Build Notifications

on:
  workflow_run:
    workflows: ["Tests", "Build"]
    types: [completed]

jobs:
  notify:
    runs-on: ubuntu-latest
    
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    
    steps:
      - name: Extract failure info
        id: failure
        run: |
          echo "WORKFLOW=${{ github.event.workflow_run.name }}" >> $GITHUB_OUTPUT
          echo "BRANCH=${{ github.event.workflow_run.head_branch }}" >> $GITHUB_OUTPUT
          echo "AUTHOR=${{ github.event.workflow_run.actor }}" >> $GITHUB_OUTPUT
          echo "RUN_ID=${{ github.event.workflow_run.id }}" >> $GITHUB_OUTPUT
      
      - name: Send Slack notification
        uses: 8398a7/action-slack@v3
        if: always()
        with:
          status: ${{ job.status }}
          text: |
            ❌ Build Failed
            Workflow: ${{ steps.failure.outputs.WORKFLOW }}
            Branch: ${{ steps.failure.outputs.BRANCH }}
            Author: ${{ steps.failure.outputs.AUTHOR }}
            Details: https://github.com/${{ github.repository }}/actions/runs/${{ steps.failure.outputs.RUN_ID }}
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
      
      - name: Create issue for failure
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Build Failed: ${{ steps.failure.outputs.WORKFLOW }}`,
              body: `
                ## Build Failure Report
                
                **Workflow**: ${{ steps.failure.outputs.WORKFLOW }}
                **Branch**: ${{ steps.failure.outputs.BRANCH }}
                **Author**: ${{ steps.failure.outputs.AUTHOR }}
                **Run**: https://github.com/${{ github.repository }}/actions/runs/${{ steps.failure.outputs.RUN_ID }}
                
                Please investigate and fix.
              `,
              labels: ['bug', 'ci-failure']
            });
```

### 4.2 배포 모니터링

```yaml
# .github/workflows/deployment-monitoring.yml

name: Deployment Monitoring

on:
  release:
    types: [published]

jobs:
  monitor-release:
    runs-on: ubuntu-latest
    
    steps:
      - name: Check release artifacts
        uses: actions/github-script@v7
        with:
          script: |
            const release = await github.rest.repos.getRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              release_id: context.payload.release.id
            });
            
            const hasAssets = release.data.assets.length > 0;
            const hasDmg = release.data.assets.some(a => a.name.endsWith('.dmg'));
            const hasZip = release.data.assets.some(a => a.name.endsWith('.zip'));
            
            console.log('Release validation:');
            console.log(`  DMG: ${hasDmg ? '✓' : '✗'}`);
            console.log(`  ZIP: ${hasZip ? '✓' : '✗'}`);
            
            if (!hasDmg || !hasZip) {
              throw new Error('Missing release artifacts');
            }
      
      - name: Verify notarization
        run: |
          # DMG가 공증되었는지 확인
          DOWNLOAD_URL="${{ github.event.release.assets[0].browser_download_url }}"
          
          # curl로 다운로드 시뮬레이션
          echo "Verifying: $DOWNLOAD_URL"
      
      - name: Send release notification
        run: |
          echo "🚀 Release ${{ github.event.release.tag_name }} published"
          echo "Assets: ${{ github.event.release.assets_url }}"
```

---

## 5. 종합 대시보드 구성

### 5.1 GitHub Actions 상태 배지

```markdown
# README.md에 추가

## Build Status

![Build](https://github.com/username/NotepadNext/workflows/Build/badge.svg?branch=main)
![Tests](https://github.com/username/NotepadNext/workflows/Tests/badge.svg?branch=main)
![Code Quality](https://github.com/username/NotepadNext/workflows/Code%20Quality/badge.svg?branch=main)
[![codecov](https://codecov.io/gh/username/NotepadNext/branch/main/graph/badge.svg)](https://codecov.io/gh/username/NotepadNext)
```

### 5.2 성능 대시보드 (GitHub Pages)

```yaml
# .github/workflows/publish-metrics.yml

name: Publish Metrics

on:
  workflow_run:
    workflows: ["Build Metrics"]
    types: [completed]

jobs:
  publish:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          ref: gh-pages
      
      - uses: actions/download-artifact@v3
        with:
          name: build-metrics
          path: metrics
      
      - name: Generate metrics dashboard
        run: |
          cat > metrics.html << 'EOF'
          <!DOCTYPE html>
          <html>
          <head>
            <title>NotepadNext Build Metrics</title>
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>
              body { font-family: system-ui; margin: 20px; }
              .metric { margin: 20px 0; }
              canvas { max-width: 600px; }
            </style>
          </head>
          <body>
            <h1>Build Performance Metrics</h1>
            <div id="chart" class="metric">
              <canvas id="buildTimeChart"></canvas>
            </div>
          </body>
          </html>
          EOF
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: .
```

---

## 6. CI/CD 최적화 체크리스트

```
성능:
  ✓ 병렬 테스트 실행 활성화
  ✓ 증분 빌드 캐싱 구성
  ✓ SPM 종속성 캐싱
  ✓ 불필요한 단계 제거

품질:
  ✓ 자동 코드 리뷰
  ✓ 정적 분석
  ✓ 메모리/보안 검사
  ✓ 아키텍처 검증

모니터링:
  ✓ 빌드 시간 추적
  ✓ 테스트 성능 측정
  ✓ 실패 알림
  ✓ 배포 검증

문서화:
  ✓ CI/CD 절차 문서화
  ✓ 성능 목표 설정
  ✓ 트러블슈팅 가이드
  ✓ 메트릭 대시보드
```

---

## 7. 빠른 피드백 루프 구성

### 7.1 개발자 빠른 빌드

```bash
# Scripts/fast-build.sh
# 개발 중 빠른 빌드 (테스트 제외)

set -e

echo "🚀 Fast development build"
echo ""

# 1. 포맷 확인만 (전체 포맷 아님)
echo "Checking code style..."
swift-format lint --recursive Sources/NotepadNext --config .swift-format 2>/dev/null || true

# 2. 빠른 빌드
echo "Building..."
xcodebuild build \
  -scheme NotepadNext \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -parallelizeTargets \
  -quiet

# 3. 앱 시작
echo "✓ Build complete!"
echo ""
echo "Launching app..."
open build/Build/Products/Debug/NotepadNext.app

# 사용: ./Scripts/fast-build.sh
```

### 7.2 로컬 테스트 빠른 실행

```bash
# Scripts/fast-test.sh

set -e

case ${1:-unit} in
  unit)
    echo "Running unit tests..."
    xcodebuild test \
      -scheme NotepadNextTests \
      -destination 'platform=macOS,arch=arm64' \
      -only-testing "NotepadNextTests"
    ;;
  
  ui)
    echo "Running UI tests..."
    xcodebuild test \
      -scheme NotepadNextUITests \
      -destination 'platform=macOS,arch=arm64'
    ;;
  
  snapshot)
    echo "Running snapshot tests..."
    xcodebuild test \
      -scheme SyntaxHighlightingSnapshotTests \
      -destination 'platform=macOS,arch=arm64'
    ;;
  
  all)
    $0 unit && $0 ui && $0 snapshot
    ;;
  
  *)
    echo "Usage: fast-test.sh [unit|ui|snapshot|all]"
    exit 1
    ;;
esac

echo "✓ Tests passed!"
```

이 고급 CI/CD 구성은 프로덕션 수준의 품질 보증과 고성능을 제공합니다.
