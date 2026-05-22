# ┌───────────────────────────────────────────────────────────────┐
# │ Justfile for tms (Go project)                                 │
# │                                                               │
# │ Commands: just → show this help message                       │
# └───────────────────────────────────────────────────────────────┘

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]
set dotenv-load := true

BIN := "./bin/tms"
VERSION_FILE := "VERSION"

# Extract version from VERSION file (fallback to 1.2.0)
version := `cat VERSION 2>/dev/null || echo "1.2.0"`

# Default recipe
default: help

# ─── Help ──────────────────────────────────────────────────────
help:
    @echo "Available commands for tms:"
    @echo ""
    @echo "=== Development ==="
    @echo " just / just help     → Show this help message"
    @echo " just build / b       → Build project"
    @echo " just run / r         → Run project"
    @echo ""
    @echo "=== Quality ==="
    @echo " just fmt             → Format code"
    @echo " just fmt-check       → Check formatting"
    @echo " just vet             → Vet code"
    @echo " just lint            → Run golangci-lint"
    @echo " just test            → Run tests"
    @echo " just check           → Run all quality checks"
    @echo ""
    @echo "=== Dependencies ==="
    @echo " just deps            → Download dependencies"
    @echo " just tidy            → Tidy go modules"
    @echo " just update          → Update dependencies"
    @echo ""
    @echo "=== Maintenance ==="
    @echo " just clean           → Remove binaries"
    @echo " just pre-commit      → Full validation before commit"
    @echo ""
    @echo "=== Release ==="
    @echo " just release-dry-run → Preview release"
    @echo " just release         → Create tag + push"
    @echo " just release-clean   → Delete old release/tag and recreate"
    @echo " just release-local   → Install locally for testing"
    @echo ""

# ─── Build & Development ───────────────────────────────────────
build:
    @echo "🔨 Building tms {{version}}..."
    @mkdir -p bin
    go build -ldflags="-s -w \
        -X main.Version={{version}} \
        -X main.GitCommit=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown') \
        -X main.BuildTime=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        -o {{BIN}} .
    @echo "✅ Build completed: {{BIN}} (v{{version}})"

run:
    @echo "🚀 Running tms..."
    go run .

b: build
r: run

# ─── Quality ───────────────────────────────────────────────────
fmt:
    @echo "🎨 Formatting code..."
    go fmt ./...

fmt-check:
    @echo "🔍 Checking formatting..."
    @sh -c 'test -z "$$(gofmt -l .)" || (echo "❌ Formatting issues found"; gofmt -l .; exit 1)'

vet:
    @echo "🔎 Running go vet..."
    go vet ./...

lint:
    @echo "🧹 Running golangci-lint..."
    golangci-lint run

test:
    @echo "🧪 Running tests..."
    go test -v -race -covermode=atomic -count=1 ./...

check:
    just fmt-check
    just vet
    just lint
    just test
    @echo "✅ All checks passed!"

# ─── Dependencies ──────────────────────────────────────────────
deps:
    @echo "📦 Downloading dependencies..."
    go mod download

tidy:
    @echo "🧹 Tidying go modules..."
    go mod tidy

update:
    @echo "⬆️ Updating dependencies..."
    go get -u ./...
    go mod tidy
    @echo "✅ Dependencies updated!"

# ─── Maintenance ───────────────────────────────────────────────
clean:
    @echo "🧹 Cleaning binaries..."
    rm -rf bin/

pre-commit:
    @echo "🚦 Running pre-commit checks..."
    just fmt
    just check
    just tidy
    @echo "🎉 Pre-commit checks completed!"

# ─── Release Artifacts Cleanup (local only) ────────────────────
clean-release-artifacts:
    @echo "🧹 Cleaning local release artifacts..."
    rm -rf bin/tms 2>/dev/null || true
    rm -rf release/*.tar.gz release/*.zip 2>/dev/null || true
    @echo "→ Local artifacts removed"

# ─── Release ───────────────────────────────────────────────────
release-dry-run:
    @echo "Current version in VERSION → {{version}}"
    @echo "Tag that will be created → v{{version}}"
    @echo ""
    @echo "This will trigger the GitHub Actions workflow to build official binaries."

release-clean:
    @echo "🧹 Preparing fresh release for v{{version}}..."
    just clean-release-artifacts
   
    @echo "→ Deleting remote GitHub Release and tag (v{{version}})..."
    gh release delete "v{{version}}" --yes --cleanup-tag 2>/dev/null \
        && echo " → Remote release + tag deleted" \
        || echo " → No previous remote release found"
   
    @echo "→ Deleting local tag (v{{version}})..."
    git tag -d "v{{version}}" 2>/dev/null \
        && echo " → Local tag deleted" \
        || echo " → No local tag found"
   
    @echo "→ Fetching latest tags from remote..."
    git fetch --tags --force
   
    @echo ""
    @echo "🚀 Starting clean release..."
    just release

release:
    @echo "=== Preparing release v{{version}} ==="
  
    just pre-commit
   
    @echo "📦 Committing dependency files (if changed)..."
    git add go.mod go.sum VERSION
    git commit -m "chore: release v{{version}}" \
        || echo "→ No changes to commit"
   
    @echo "🏷️ Creating annotated tag v{{version}}..."
    git tag -a "v{{version}}" -m "Release v{{version}}"
   
    @echo "⬆️ Pushing commit and tag to GitHub..."
    git push origin main --follow-tags
   
    @echo ""
    @echo "🎉 Tag v{{version}} pushed successfully!"
    @echo "→ GitHub Actions is now building the official binaries and creating the release."

# Local install (for testing only)
release-local:
    @echo "📦 Installing tms locally..."
    just build
    go install .
    @echo "✅ tms installed locally from source"
