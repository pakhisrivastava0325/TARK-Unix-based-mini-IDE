#!/usr/bin/env bash
# End-to-end tests for the synopsis requirements. Run on Ubuntu/Linux.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export TARK_WORKSPACE="$TMP/workspace"
mkdir -p "$TARK_WORKSPACE"
command -v gcc >/dev/null || { echo 'gcc is required'; exit 1; }
command -v make >/dev/null || { echo 'make is required'; exit 1; }
pass=0
check_contains() {
  local label="$1" cmd="$2" expected="$3" out
  out="$(bash "$HERE/tark.sh" -c "$cmd" 2>&1)" || { echo "[FAIL] $label"; echo "$out"; exit 1; }
  grep -qF -- "$expected" <<<"$out" || { echo "[FAIL] $label (missing '$expected')"; echo "$out"; exit 1; }
  echo "[PASS] $label"; pass=$((pass+1))
}

printf 'alpha\nbeta\ngamma\n' > "$TARK_WORKSPACE/input.txt"
check_contains 'fork/exec/wait child execution' 'process run "printf child-process-ok"' 'Parent resumed after wait()'
check_contains 'pipe() and two child processes' 'pipes pipe "printf beta" "grep beta"' 'beta'
check_contains 'input redirection with dup2()' 'pipes input input.txt "wc -l"' '3'
check_contains 'output redirection with dup2()' 'pipes output redirected.txt "printf output-ok"' 'dup2()'
[[ "$(cat "$TARK_WORKSPACE/redirected.txt")" == 'output-ok' ]] || { echo '[FAIL] redirected output content'; exit 1; }
echo '[PASS] redirected output content'; pass=$((pass+1))
check_contains 'append redirection' 'pipes append redirected.txt "printf append-ok"' 'dup2()'
[[ "$(cat "$TARK_WORKSPACE/redirected.txt")" == 'output-okappend-ok' ]] || { echo '[FAIL] append content'; exit 1; }
echo '[PASS] append content'; pass=$((pass+1))
check_contains 'Makefile project scaffold' 'make init' 'multi-file C project'
check_contains 'multi-file compilation' 'make' 'gcc build/main.o build/message.o -o build/app'
check_contains 'Makefile test target' 'make test' 'PASS: application output test'
check_contains 'build/test report' 'report' 'EXIT_STATUS=0'
echo "All $pass Ubuntu feature tests passed."
