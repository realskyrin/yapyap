#!/bin/bash
#
# Quick compile-check for yapyap.
#
# Looks at build-relevant files changed since HEAD (including untracked new
# files), runs an incremental Xcode debug build, and surfaces only
# compilation/linker errors.
#
# Exits 0 when the current tree compiles cleanly (or has nothing to check),
# and 1 when the compiler or linker reports errors.
#
set -eo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="yapyap"
SCHEME="yapyap"
PROJECT_FILE="$PROJECT_ROOT/$APP_NAME.xcodeproj"
PROJECT_SPEC="$PROJECT_ROOT/project.yml"
PBXPROJ_FILE="$PROJECT_FILE/project.pbxproj"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA_PATH="$BUILD_DIR/CompileCheckDerivedData"
LOCK_DIR="$BUILD_DIR/.compile-check.lock"

mkdir -p "$BUILD_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "✗ compile-check is already running in this repo"
  exit 1
fi

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

trap cleanup EXIT

# Modified tracked files (excluding deletions) + untracked files, deduped.
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  changed_files=$( { \
      git diff --name-only --diff-filter=d HEAD; \
      git ls-files --others --exclude-standard; \
    } | sort -u)
else
  changed_files=$(git ls-files --others --exclude-standard | sort -u)
fi

if [ -z "$changed_files" ]; then
  echo "No modified files found — nothing to check."
  exit 0
fi

# Filter to files that can affect the Xcode build.
relevant=()
while IFS= read -r file; do
  [ -z "$file" ] && continue
  case "$file" in
    *.swift|*.h|*.m|*.mm|*.c|*.cc|*.cpp|project.yml|Package.resolved|*.xcconfig|*.entitlements|*.plist)
      relevant+=("$file")
      ;;
  esac
done <<< "$changed_files"

if [ ${#relevant[@]} -eq 0 ] && [ ! -f "$PBXPROJ_FILE" ]; then
  relevant+=("project.yml")
fi

if [ ${#relevant[@]} -eq 0 ]; then
  echo "No build-relevant files changed — skipping compile check."
  exit 0
fi

echo "Changed build inputs:"
printf '  %s\n' "${relevant[@]}"
echo ""

if [ ! -f "$PBXPROJ_FILE" ] || [ "$PROJECT_SPEC" -nt "$PBXPROJ_FILE" ]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen is required to generate $APP_NAME.xcodeproj"
    exit 1
  fi
  echo "Refreshing Xcode project with xcodegen..."
  xcodegen generate -q
  echo ""
fi

build_cmd=(
  xcodebuild
  -project "$PROJECT_FILE"
  -scheme "$SCHEME"
  -configuration Debug
  -destination "platform=macOS,arch=arm64"
  -derivedDataPath "$DERIVED_DATA_PATH"
  CODE_SIGNING_ALLOWED=NO
  build
  -quiet
)

echo "Running: ${build_cmd[*]}"
echo ""

# Run xcodebuild and capture combined output. Xcode emits compiler
# diagnostics in the form "<path>:<line>:<col>: error: <message>" and linker
# diagnostics prefixed with "ld:" / "Undefined symbols".
set +e
build_output=$("${build_cmd[@]}" 2>&1)
exit_code=$?
set -e

# Extract error lines only (compiler + linker). Match:
#   /abs/path/File.swift:12:5: error: ...
#   error: ...
#   ld: ...
#   Undefined symbols ...
errors=$(printf '%s\n' "$build_output" \
  | grep -E '(^/.*:[0-9]+:[0-9]+: error: |^error: |^ld: |Undefined symbols|Command .* failed with a nonzero exit code)' \
  || true)

if [ -n "$errors" ]; then
  echo "✗ Compilation errors found:"
  echo ""
  echo "$errors"
  exit 1
elif [ $exit_code -ne 0 ]; then
  echo "✗ Build failed with non-compilation error:"
  echo ""
  echo "$build_output"
  exit 1
else
  echo "✓ No compilation errors found"
  exit 0
fi
