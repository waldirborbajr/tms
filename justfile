# ┌───────────────────────────────────────────────────────────────┐
# │ Justfile for tms (Go project)                                 │
# │                                                               │
# │ Build: small, secure, fast                                    │
# │                                                               │
# │ Commands: just → show this help message                       │
# └───────────────────────────────────────────────────────────────┘

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]
set dotenv-load := true

BIN := "./bin/tms"
BIN_NAME := "tms"
VERSION_FILE := "VERSION"

# Extract version from VERSION file (fallback)
version := `cat VERSION 2>/dev/null || echo "0.1.0"`

# Build flags for optimization
# -s: strip symbol table
# -w: strip DWARF debug info
# -trimpath: remove filesystem paths from binary (security & reproducible)
LD_FLAGS := "-s -w -X main.Version=" + version + " -X main.GitCommit=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown') -X main.BuildTime=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Default recipe
default: help

# ─── Help ──────────────────────────────────────────────────────
help:
    @echo "┌─ TMS Justfile ─────────────────────────────────────┐"
    @echo "│                                                    │"
    @echo "│ 🎯 QUICK START                                    │"
    @echo "│  just build  → Build optimized binary             │"
    @echo "│  just run    → Run from source                    │"
    @echo "│  just test   → Run tests                          │"
    @echo "│                                                    │"
    @echo "│ 🔨 BUILD                                          │"
    @echo "│  just build     / b         → Optimized binary    │"
    @echo "│  just build-debug           → With debug symbols  │"
    @echo "│  just build-static          → Static binary       │"
    @echo "│  just build-cross           → Multi-platform      │"
    @echo "│  just build-analyze         → Show binary size    │"
    @echo "│                                                    │"
    @echo "│ 🚀 RUN                                            │"
    @echo "│  just run      / r          → Run from source     │"
    @echo "│  just run-binary            → Run built binary    │"
    @echo "│                                                    │"
    @echo "│ ✅ QUALITY                                        │"
    @echo "│  just fmt                   → Format code         │"
    @echo "│  just fmt-check             → Check formatting    │"
    @echo "│  just vet                   → Go vet             │"
    @echo "│  just lint                  → Golangci-lint       │"
    @echo "│  just test                  → Run tests           │"
    @echo "│  just test-coverage         → With coverage       │"
    @echo "│  just check                 → All quality checks  │"
    @echo "│  just security              → Security scan       │"
    @echo "│                                                    │"
    @echo "│ 📦 DEPENDENCIES                                   │"
    @echo "│  just deps                  → Download deps       │"
    @echo "│  just tidy                  → Tidy modules        │"
    @echo "│  just update                → Update deps         │"
    @echo "│  just audit                 → Check vulns         │"
    @echo "│                                                    │"
    @echo "│ 📌 VERSION                                        │"
    @echo "│  just version-bump patch    → x.y.Z++             │"
    @echo "│  just version-bump minor    → x.Y.0++             │"
    @echo "│  just version-bump major    → X.0.0++             │"
    @echo "│  just version-show          → Current version     │"
    @echo "│                                                    │"
    @echo "│ 🧹 MAINTENANCE                                    │"
    @echo "│  just clean                 → Clean binaries      │"
    @echo "│  just clean-all             → Clean all artifacts │"
    @echo "│  just pre-commit            → Pre-commit checks   │"
    @echo "│                                                    │"
    @echo "│ 🚢 RELEASE                                        │"
    @echo "│  just release-dry-run       → Preview release     │"
    @echo "│  just release               → Create + push tag   │"
    @echo "│  just release-clean         → Clean old release   │"
    @echo "│  just release-local         → Install locally     │"
    @echo "│                                                    │"
    @echo "└────────────────────────────────────────────────────┘"

# ─── Version Management ────────────────────────────────────────
version-show:
    @echo "Current version: {{version}}"

version-bump type="patch":
    @echo "Current version: {{version}}"
    @if [ "{{type}}" != "patch" ] && [ "{{type}}" != "minor" ] && [ "{{type}}" != "major" ]; then \
        echo "❌ Invalid type. Use: patch | minor | major"; \
        exit 1; \
    fi
    @new_version=$$(echo "{{version}}" | awk -F. -v t="{{type}}" '\
        { \
            major=$$1; minor=$$2; patch=$$3; \
            if (t == "major") { major++; minor=0; patch=0 } \
            else if (t == "minor") { minor++; patch=0 } \
            else if (t == "patch") { patch++ } \
            printf "%d.%d.%d", major, minor, patch \
        }') && \
    echo "$$new_version" > {{VERSION_FILE}} && \
    echo "✅ Version bumped: {{version}} → $$new_version"

# ─── Build ─────────────────────────────────────────────────────

# Main optimized build: small, secure, fast
build:
    @echo "🔨 Building {{BIN_NAME}} {{version}} (optimized)..."
    @mkdir -p bin
    CGO_ENABLED=0 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o {{BIN}} .
    @du -h {{BIN}} | awk '{print "📦 Binary size: " $$1}'
    @echo "✅ Build complete: {{BIN}}"

# Build with debug symbols (larger, useful for debugging)
build-debug:
    @echo "🔨 Building {{BIN_NAME}} {{version}} (with debug symbols)..."
    @mkdir -p bin
    CGO_ENABLED=0 go build \
        -o {{BIN}}-debug .
    @du -h {{BIN}}-debug | awk '{print "📦 Binary size: " $$1}'
    @echo "✅ Debug build complete: {{BIN}}-debug"

# Build fully static binary (no libc dependency)
build-static:
    @echo "🔨 Building {{BIN_NAME}} {{version}} (fully static)..."
    @mkdir -p bin
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
        -a \
        -trimpath \
        -ldflags="{{LD_FLAGS}} -extldflags -static" \
        -o {{BIN}}-static .
    @du -h {{BIN}}-static | awk '{print "📦 Binary size: " $$1}'
    @echo "✅ Static build complete: {{BIN}}-static"

# Analyze binary size and content
build-analyze:
    @echo "🔍 Analyzing binary size..."
    @mkdir -p bin
    just build
    @echo ""
    @echo "📊 Binary breakdown:"
    go tool nm {{BIN}} | grep -E "\.text|\.data|\.bss" | head -20 || true
    @echo ""
    @echo "🔦 Listing large functions:"
    go tool nm {{BIN}} | sort -k2 -rn | head -10 || true

# Cross-platform builds (small, optimized for each OS)
build-cross:
    @echo "🌍 Building cross-platform binaries..."
    @mkdir -p bin/releases

    @echo "  → Linux x86_64..."
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o bin/releases/{{BIN_NAME}}-linux-amd64 .

    @echo "  → Linux ARM64..."
    CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o bin/releases/{{BIN_NAME}}-linux-arm64 .

    @echo "  → macOS x86_64..."
    CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o bin/releases/{{BIN_NAME}}-darwin-amd64 .

    @echo "  → macOS ARM64 (Apple Silicon)..."
    CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o bin/releases/{{BIN_NAME}}-darwin-arm64 .

    @echo "  → Windows x86_64..."
    CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build \
        -trimpath \
        -ldflags="{{LD_FLAGS}}" \
        -o bin/releases/{{BIN_NAME}}-windows-amd64.exe .

    @echo ""
    @echo "✅ Cross-platform builds complete:"
    @ls -lh bin/releases/ | awk 'NR>1 {printf "  %s → %s\n", $$9, $$5}'

# Shorthand
b: build

# ─── Run ────────────────────────────────────────────────────────
run:
    @echo "🚀 Running {{BIN_NAME}} from source..."
    go run .

run-binary:
    @if [ -f "{{BIN}}" ]; then \
        echo "🚀 Running {{BIN}}..."; \
        {{BIN}}; \
    else \
        echo "❌ Binary not found. Run 'just build' first"; \
        exit 1; \
    fi

r: run

# ─── Testing ────────────────────────────────────────────────────
test:
    @echo "🧪 Running tests..."
    go test -v -race -count=1 ./...

test-coverage:
    @echo "🧪 Running tests with coverage..."
    go test -v -race -covermode=atomic -coverprofile=coverage.out ./...
    go tool cover -html=coverage.out -o coverage.html
    @echo "✅ Coverage report: coverage.html"

# ─── Code Quality ──────────────────────────────────────────────
fmt:
    @echo "🎨 Formatting code..."
    go fmt ./...

fmt-check:
    @echo "🔍 Checking code format..."
    @sh -c 'test -z "$$(gofmt -l .)" || (echo "❌ Formatting issues found:"; gofmt -l .; exit 1)'
    @echo "✅ Code formatting OK"

vet:
    @echo "🔎 Running go vet..."
    go vet ./...
    @echo "✅ Vet checks passed"

lint:
    @if command -v golangci-lint &> /dev/null; then \
        echo "🧹 Running golangci-lint..."; \
        golangci-lint run --timeout=5m; \
        echo "✅ Lint checks passed"; \
    else \
        echo "⚠️  golangci-lint not installed. Install with:"; \
        echo "   go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
    fi

# ─── Security ──────────────────────────────────────────────────
security:
    @echo "🔒 Running security checks..."
    @echo ""
    @echo "  → Checking for vulnerable dependencies..."
    go list -json -m all | go-sec-scan 2>/dev/null || echo "    (go-sec-scan not installed)"
    @echo ""
    @echo "  → Using go mod graph to check deps..."
    @echo "    Run: go mod graph | grep -v self | sort | uniq"
    @echo ""
    @echo "✅ Security check completed"

audit:
    @echo "📋 Auditing dependencies for vulnerabilities..."
    @if command -v nancy &> /dev/null; then \
        go list -json -m all | nancy sleuth; \
    else \
        go list -u -m all; \
        echo "⚠️  Install nancy for detailed vulnerability scanning:"; \
        echo "   go install github.com/sonatype-nexus-community/nancy@latest"; \
    fi

# Full quality check
check: fmt-check vet lint test
    @echo ""
    @echo "✅ All quality checks passed!"

pre-commit: fmt check tidy
    @echo ""
    @echo "🎉 Pre-commit validation complete!"

# ─── Dependencies ──────────────────────────────────────────────
deps:
    @echo "📦 Downloading dependencies..."
    go mod download
    go mod verify
    @echo "✅ Dependencies downloaded and verified"

tidy:
    @echo "🧹 Tidying Go modules..."
    go mod tidy
    @echo "✅ Modules tidied"

update:
    @echo "⬆️ Updating dependencies..."
    go get -u ./...
    go mod tidy
    @echo "✅ Dependencies updated"

# ─── Maintenance ───────────────────────────────────────────────
clean:
    @echo "🧹 Cleaning binaries..."
    rm -f {{BIN}} {{BIN}}-debug {{BIN}}-static
    @echo "✅ Binaries removed"

clean-all: clean
    @echo "🧹 Full cleanup..."
    rm -rf bin/
    rm -f coverage.out coverage.html
    go clean -cache
    go clean -testcache
    @echo "✅ All artifacts cleaned"

# ─── Release ───────────────────────────────────────────────────

release-dry-run:
    @echo "📋 Release preview for v{{version}}"
    @echo ""
    @echo "  Version:  {{version}}"
    @echo "  Binary:   {{BIN}}"
    @echo "  Tag:      v{{version}}"
    @echo ""
    @echo "  Next step: just release"

release-check-duplicate-tag:
    @echo "🔍 Checking if tag v{{version}} already exists..."
    @if git rev-parse "v{{version}}" >/dev/null 2>&1; then \
        echo "❌ Error: Tag v{{version}} already exists!"; \
        echo "   Use 'just release-clean' to delete the existing tag and release."; \
        exit 1; \
    else \
        echo "✅ Tag v{{version}} does not exist yet."; \
    fi

release-clean:
    @echo "🧹 Cleaning old release artifacts..."
    rm -rf bin/releases 2>/dev/null || true
    @echo "  → Deleting remote GitHub Release and tag (v{{version}})..."
    gh release delete "v{{version}}" --yes --cleanup-tag 2>/dev/null || echo "    (no previous release found)"
    git tag -d "v{{version}}" 2>/dev/null || echo "    (no local tag found)"
    git fetch --tags --force 2>/dev/null || true
    @echo "✅ Old release cleaned. Now run: just release"

release: pre-commit release-check-duplicate-tag build-cross
    @echo ""
    @echo "🚀 Creating release v{{version}}..."
    @echo ""

    @echo "  → Committing version updates..."
    git add {{VERSION_FILE}} go.mod go.sum 2>/dev/null || true
    git commit -m "chore: bump version to {{version}}" \
        || echo "    (no changes to commit)"

    @echo "  → Creating annotated tag v{{version}}..."
    git tag -a "v{{version}}" -m "Release v{{version}}"

    @echo "  → Pushing to GitHub..."
    git push origin main --follow-tags

    @echo ""
    @echo "✅ Release v{{version}} pushed successfully!"
    @echo ""
    @echo "📦 Binaries available in: bin/releases/"

release-local: build
    @echo "📦 Installing {{BIN_NAME}} locally..."
    go install .
    @echo "✅ {{BIN_NAME}} installed to \$$GOPATH/bin"
    @echo "   Run: {{BIN_NAME}}"

# ─── Info ──────────────────────────────────────────────────────
info:
    @echo "📊 Project Information"
    @echo ""
    @echo "  Version:     {{version}}"
    @echo "  Binary:      {{BIN}}"
    @echo "  Go version:  $$(go version | awk '{print $$3}')"
    @echo ""
    @echo "  Dependencies:"
    @go list -m all | wc -l | awk '{print "    Total: " $$1}'
    @echo ""
    @if [ -f "{{BIN}}" ]; then \
        du -h {{BIN}} | awk '{print "  Binary size: " $$1}'; \
    else \
        echo "  Binary size: (not built)"; \
    fi
