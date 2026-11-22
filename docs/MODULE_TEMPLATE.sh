#!/usr/bin/env bash
# =============================================================================
# TEMPLATE for a TARK module.
#
# 1) Copy this file into the  modules/  folder and rename it (e.g. compile.sh).
# 2) Keep ONLY the function(s) that belong to your part, and fill them in.
# 3) Run ./tark.sh and type 'status' - your part must show a green tick.
#
# RULES (same as the Search & Utilities module)
#   - Print results to the screen, error messages to stderr  (echo "..." >&2)
#   - Use  return  (never  exit)  so the whole IDE does not close.
#   - Return codes:  0 = success,  1 = error,  2 = nothing found / failed build
#   - Quote every variable: "$file"   (so names with spaces work)
#   - Files live in the current folder (the IDE already moved into workspace/)
# =============================================================================

# Called by:  compile  /  compile hello.c  /  menu option 3
tark_compile() {
    local file="${1:-}"
    echo "Compiling '$file' ..."
    # e.g.  gcc -Wall -o "${file%.c}" "$file"
}

# Called by:  run  /  run hello.c  /  menu option 3 (after compile)
tark_run() {
    local file="${1:-}"; shift
    echo "Running '$file' ..."
    # e.g.  "./${file%.c}" "$@"
}

# Called by:  process  /  ps  /  menu option 4
tark_process() { echo "Process management ..."; }

# Called by:  pipes  /  menu option 5
tark_pipes()   { echo "Pipes and redirection ..."; }

# Called by:  make  /  project  /  menu option 6
tark_make()    { echo "Makefile project ..."; }

# Called by:  report  /  menu option 7
tark_report()  { echo "Build and test report ..."; }
