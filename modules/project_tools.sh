#!/usr/bin/env bash
# TARK project/build/report/pipeline integration module.

_tark_tool_dir="$TARK_WORKSPACE/.tark/bin"
_tark_report_dir="$TARK_WORKSPACE/.tark/reports"
_tark_helper_src="$TARK_DIR/modules/tark_system.c"
_tark_helper="$_tark_tool_dir/tark_sys"

_tark_ensure_helper() {
    mkdir -p "$_tark_tool_dir" || return 1
    if [[ ! -x "$_tark_helper" || "$_tark_helper_src" -nt "$_tark_helper" ]]; then
        command -v gcc >/dev/null 2>&1 || { echo "[TARK] gcc is required to build the Unix system-call helper." >&2; return 1; }
        gcc -std=c11 -Wall -Wextra -O2 -o "$_tark_helper" "$_tark_helper_src" || return 1
    fi
}

tark_process() {
    if [[ "${1:-}" == "run" ]]; then
        shift
        [[ $# -gt 0 ]] || { echo "Usage: process run \"command\""; return 2; }
        _tark_ensure_helper && "$_tark_helper" proc "$*"
    else
        show_processes
        echo
        echo "Tip: process run \"sleep 2; echo child finished\" demonstrates fork(), exec(), and wait()."
    fi
}

tark_pipes() {
    local mode="${1:-}" file="${2:-}" command="${3:-}"
    _tark_ensure_helper || return 1
    case "$mode" in
        pipe)
            [[ $# -ge 3 ]] || { echo 'Usage: pipes pipe "command 1" "command 2"'; return 2; }
            "$_tark_helper" pipe "$2" "$3" ;;
        input|"<")
            [[ $# -ge 3 ]] || { echo 'Usage: pipes input <file> "command"'; return 2; }
            "$_tark_helper" input "$file" "$command" ;;
        output|">")
            [[ $# -ge 3 ]] || { echo 'Usage: pipes output <file> "command"'; return 2; }
            "$_tark_helper" output "$file" "$command" ;;
        append|">>")
            [[ $# -ge 3 ]] || { echo 'Usage: pipes append <file> "command"'; return 2; }
            "$_tark_helper" append "$file" "$command" ;;
        *)
            cat <<'HELP'
PIPES & REDIRECTION (implemented with pipe(), fork(), and dup2())
  pipes pipe "printf 'one\\ntwo\\n'" "grep two"
  pipes input input.txt "wc -l"
  pipes output result.txt "ls -la"
  pipes append result.txt "date"
HELP
            return 0 ;;
    esac
}

_tark_makefile_template() {
    cat > Makefile <<'MAKE'
CC      := gcc
CFLAGS  := -Wall -Wextra -std=c11 -Iinclude
SRC     := $(wildcard src/*.c)
OBJ     := $(patsubst src/%.c,build/%.o,$(SRC))
TARGET  := build/app

.PHONY: all clean test
all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(OBJ) -o $@

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build:
	mkdir -p build

test: all
	bash tests/test.sh

clean:
	rm -rf build
MAKE
}

tark_make() {
    local action="${1:-all}" stamp log rc
    if [[ "$action" == "init" ]]; then
        if [[ -e Makefile ]]; then echo "[TARK] Makefile already exists; not overwriting."; return 1; fi
        mkdir -p src include tests
        _tark_makefile_template || return 1
        cat > include/message.h <<'H'
#ifndef TARK_MESSAGE_H
#define TARK_MESSAGE_H
void print_message(void);
#endif
H
        cat > src/main.c <<'C'
#include "message.h"
int main(void) { print_message(); return 0; }
C
        cat > src/message.c <<'C'
#include <stdio.h>
#include "message.h"
void print_message(void) { puts("TARK multi-file project is working!"); }
C
        cat > tests/test.sh <<'TEST'
#!/usr/bin/env bash
set -euo pipefail
output="$(./build/app)"
[[ "$output" == "TARK multi-file project is working!" ]]
echo "PASS: application output test"
TEST
        chmod +x tests/test.sh
        echo "[TARK] Created a sample multi-file C project (Makefile, src/, include/, tests/)."
        echo "Run: make   then   make test"
        return 0
    fi
    command -v make >/dev/null 2>&1 || { echo "[TARK] GNU make is not installed."; return 127; }
    [[ -f Makefile ]] || { echo "[TARK] No Makefile in $PWD. Run 'make init' to create a starter multi-file project."; return 1; }
    mkdir -p "$_tark_report_dir"
    stamp="$(date +%Y%m%d_%H%M%S)"
    log="$_tark_report_dir/${action}_${stamp}.log"
    echo "[TARK] Running make $action (log: $log)"
    make "$action" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    printf 'COMMAND=make %s\nEXIT_STATUS=%s\nTIMESTAMP=%s\n' "$action" "$rc" "$(date -Is)" >> "$log"
    printf '%s\n' "$log" > "$_tark_report_dir/latest_build_path"
    return "$rc"
}

tark_report() {
    mkdir -p "$_tark_report_dir"
    local latest="$_tark_report_dir/latest_build_path" path
    if [[ -f "$latest" ]]; then
        path="$(cat "$latest")"
        if [[ -f "$path" ]]; then
            echo "================ LAST BUILD / TEST REPORT ================"
            cat "$path"
            echo "=========================================================="
            return 0
        fi
    fi
    echo "[TARK] No build/test report yet. Run 'make' or 'make test' first."
    echo "Reports are stored in: $_tark_report_dir"
}
