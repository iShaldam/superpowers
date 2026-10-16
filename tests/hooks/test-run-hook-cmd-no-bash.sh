#!/usr/bin/env bash
# Tests for the Unix half of hooks/run-hook.cmd on machines without bash:
# it should fall back to zsh, and exit 0 quietly when there is no zsh either.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRAPPER="$REPO_ROOT/hooks/run-hook.cmd"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

# A PATH directory holding only the named tools, so "no bash" is real.
make_bin() {
    local dir="$TEST_ROOT/$1"
    shift
    mkdir -p "$dir"
    local tool path
    for tool in "$@"; do
        path="$(command -v "$tool" || true)"
        [[ -n "$path" ]] && ln -s "$path" "$dir/$tool"
    done
    printf '%s\n' "$dir"
}

# The wrapper is started by zsh (or dash), never bash, so $BASH is unset.
# Hook = a tiny script that proves which shell ran it.
mkdir -p "$TEST_ROOT/plugin/hooks"
cp "$WRAPPER" "$TEST_ROOT/plugin/hooks/run-hook.cmd"
printf 'echo "ran under ${ZSH_VERSION:+zsh}"\n' > "$TEST_ROOT/plugin/hooks/probe"
RUN="$TEST_ROOT/plugin/hooks/run-hook.cmd"

if ! command -v zsh >/dev/null 2>&1; then
    echo "SKIP: zsh not available"
    exit 0
fi

zsh_only="$(make_bin zsh-only zsh dirname)"
out="$(env -i PATH="$zsh_only" "$(command -v zsh)" "$RUN" probe 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 0 && "$out" == "ran under zsh" ]]; then
    pass "no bash on PATH: hook runs under zsh"
else
    fail "no bash on PATH: hook runs under zsh (exit $rc, output: $out)"
fi

nothing="$(make_bin nothing dirname)"
out="$(env -i PATH="$nothing" "$(command -v zsh)" "$RUN" probe 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then
    pass "no bash and no zsh on PATH: exits 0 silently"
else
    fail "no bash and no zsh on PATH: exits 0 silently (exit $rc, output: $out)"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
