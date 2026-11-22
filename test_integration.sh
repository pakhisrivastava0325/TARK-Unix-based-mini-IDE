#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export TARK_WORKSPACE="$TMP/workspace"
mkdir -p "$TARK_WORKSPACE"
cat > "$TARK_WORKSPACE/smoke.c" <<'C'
#include <stdio.h>
int main(void) { puts("TARK_INTEGRATION_OK"); return 0; }
C
fail=0
check() {
  local label="$1" command="$2" expected="$3" output
  output="$(bash "$HERE/tark.sh" -c "$command" 2>&1)" || {
    echo "[FAIL] $label (non-zero exit)"; fail=$((fail+1)); return; }
  if grep -qF -- "$expected" <<<"$output"; then
    echo "[PASS] $label"
  else
    echo "[FAIL] $label (expected: $expected)"
    echo "$output"
    fail=$((fail+1))
  fi
}
check "all modules loaded" "status" "✔ Run ready"
check "compile adapter" "compile smoke.c" "Compilation successful"
check "smart run adapter" "run smoke.c" "TARK_INTEGRATION_OK"
check "system information" "sysinfo" "SYSTEM INFORMATION"
check "process listing" "process" "PROCESSES OF USER"
check "permissions utility" "perms smoke.c" "Permissions of 'smoke.c'"
check "file-management module loaded" "status" "file_management.sh"
if (( fail == 0 )); then echo "All integration smoke tests passed."; else exit 1; fi
