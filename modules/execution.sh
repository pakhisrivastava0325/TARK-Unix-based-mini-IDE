#!/bin/bash
# =====================================================================
#  TARK - Unix-Based Mini IDE
#  Module   : Execution & System Utility Module (Nysa's module)
#  File     : execution.sh
#
#  HOW TO USE
#   1) Standalone :  ./execution.sh run hello.c
#                    ./execution.sh            (opens a small menu)
#   2) Integrated :  source ./execution.sh     (inside main TARK script)
#                    execute_program "hello.c"
#
#  When this file is "sourced", it only defines functions and does NOT
#  run anything by itself. That makes it safe for Pakhi to include.
#
#  RETURN CODES used by our functions
#    0 = success
#    1 = general error (bad input, compile error, unsupported type...)
#    2 = file not found
#    3 = permission denied
#    4 = required tool missing (e.g. gcc)
#    Any other number from run_* = the exit status of the user's program
# =====================================================================

# Folder where compiled programs are stored (can be changed by the
# main script by setting TARK_BIN_DIR before sourcing this file).
EXEC_OUT_DIR="${TARK_BIN_DIR:-./tark_bin}"

# After compile_c succeeds, the path of the new executable is kept here
# so that other functions (like run_c) can use it.
LAST_EXE=""

# ---------------------------------------------------------------------
# Small helper functions for printing messages
# ---------------------------------------------------------------------
print_ok()   { echo "[OK]    $*"; }
print_info() { echo "[INFO]  $*"; }
print_err()  { echo "[ERROR] $*" >&2; }   # errors go to stderr

# ---------------------------------------------------------------------
# check_gcc : is the GCC compiler installed?
# ---------------------------------------------------------------------
check_gcc() {
    if ! command -v gcc >/dev/null 2>&1; then
        print_err "GCC compiler not found."
        print_info "Install it with:  sudo apt update && sudo apt install gcc"
        return 4
    fi
    return 0
}

# ---------------------------------------------------------------------
# validate_file <path> : common checks used before every operation
#   - name given?  exists?  is a regular file (not a folder)?  readable?
# ---------------------------------------------------------------------
validate_file() {
    local file="$1"

    if [[ -z "$file" ]]; then
        print_err "No filename given."
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        print_err "File not found: '$file'"
        return 2
    fi
    if [[ -d "$file" ]]; then
        print_err "'$file' is a directory, not a file."
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        print_err "'$file' is not a regular file."
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        print_err "Permission denied: cannot read '$file'."
        print_info "Try:  chmod u+r '$file'"
        return 3
    fi
    return 0
}

# ---------------------------------------------------------------------
# explain_exit_status <status> : print a friendly message for the exit
# status of a program that has just finished.
# ---------------------------------------------------------------------
explain_exit_status() {
    local status="$1"

    if [[ "$status" -eq 0 ]]; then
        print_ok "Program finished successfully (exit status 0)."
    elif [[ "$status" -eq 126 ]]; then
        print_err "Permission problem: file found but cannot be executed (status 126)."
    elif [[ "$status" -eq 127 ]]; then
        print_err "Command not found (status 127)."
    elif [[ "$status" -gt 128 ]]; then
        # Status above 128 means the program was killed by a signal.
        local sig=$((status - 128))
        local name
        name=$(kill -l "$sig" 2>/dev/null)
        print_err "Program was terminated by signal $sig (${name:-unknown}) - status $status."
        if [[ "$sig" -eq 11 ]]; then
            print_info "SIGSEGV = segmentation fault (bad memory access in the C code)."
        fi
    else
        print_err "Program ended with a non-zero exit status: $status"
    fi
}

# ---------------------------------------------------------------------
# run_with_time <command> [args...] : run a command, measure its time
# using the shell's built-in 'time', then explain its exit status.
# Returns the exit status of the command itself.
# ---------------------------------------------------------------------
run_with_time() {
    local status
    local TIMEFORMAT=$'\n[TIME]  real: %3lR   user: %3lU   sys: %3lS'

    time "$@"
    status=$?

    explain_exit_status "$status"
    return "$status"
}

# =====================================================================
#  A. COMPILE AND RUN
# =====================================================================

# ---------------------------------------------------------------------
# compile_c <file.c> [output_name]
#   Compiles a C file with gcc. Executable goes to $EXEC_OUT_DIR.
#   On success sets LAST_EXE. On failure shows the gcc error messages.
# ---------------------------------------------------------------------
compile_c() {
    local src="$1"
    local name="$2"
    local rc

    check_gcc || return $?
    validate_file "$src" || return $?

    if [[ "$src" != *.c ]]; then
        print_err "'$src' is not a C source file (must end with .c)."
        return 1
    fi

    # Default executable name = file name without folder and without .c
    if [[ -z "$name" ]]; then
        name="$(basename "$src" .c)"
    fi

    mkdir -p "$EXEC_OUT_DIR" 2>/dev/null
    if [[ ! -w "$EXEC_OUT_DIR" ]]; then
        print_err "Permission denied: cannot write to '$EXEC_OUT_DIR'."
        return 3
    fi

    local out="$EXEC_OUT_DIR/$name"
    local errfile
    errfile="$(mktemp)"          # temporary file to catch gcc messages

    print_info "Compiling '$src' ..."
    gcc -Wall -o "$out" "$src" 2>"$errfile"
    rc=$?

    if [[ $rc -ne 0 ]]; then
        print_err "Compilation FAILED. gcc reported:"
        echo "-----------------------------------------"
        cat "$errfile" >&2
        echo "-----------------------------------------"
        rm -f "$errfile"
        LAST_EXE=""
        return 1
    fi

    # Compilation worked; show warnings (if any) so the user can fix them.
    if [[ -s "$errfile" ]]; then
        print_info "Compiled with warnings:"
        cat "$errfile"
    fi
    rm -f "$errfile"

    LAST_EXE="$out"
    print_ok "Compilation successful -> $out"
    return 0
}

# ---------------------------------------------------------------------
# run_c <file.c> [program arguments...]
#   Compile, then run the program and show its output and run time.
# ---------------------------------------------------------------------
run_c() {
    local src="$1"
    shift                         # remaining arguments go to the program

    compile_c "$src" || return $?

    echo "================ OUTPUT ================"
    run_with_time "$LAST_EXE" "$@"
    local status=$?
    echo "========================================"
    return "$status"
}

# ---------------------------------------------------------------------
# run_shell <script.sh> [arguments...]
#   Runs a shell script using bash. (File need not be executable
#   because we call 'bash script' directly.)
# ---------------------------------------------------------------------
run_shell() {
    local script="$1"
    shift

    if ! command -v bash >/dev/null 2>&1; then
        print_err "bash not found on this system."
        return 4
    fi
    validate_file "$script" || return $?

    echo "================ OUTPUT ================"
    run_with_time bash "$script" "$@"
    local status=$?
    echo "========================================"
    return "$status"
}

# ---------------------------------------------------------------------
# run_executable <file> [arguments...]
#   Runs an already compiled program / executable file.
# ---------------------------------------------------------------------
run_executable() {
    local exe="$1"
    shift

    validate_file "$exe" || return $?

    if [[ ! -x "$exe" ]]; then
        print_err "'$exe' is not executable (no execute permission)."
        print_info "Fix it with:  chmod +x '$exe'"
        return 3
    fi

    # A path like "prog" without a slash would be searched in PATH,
    # so we add "./" to make sure the file in this folder is run.
    if [[ "$exe" != */* ]]; then
        exe="./$exe"
    fi

    echo "================ OUTPUT ================"
    run_with_time "$exe" "$@"
    local status=$?
    echo "========================================"
    return "$status"
}

# =====================================================================
#  B. EXECUTION MANAGEMENT
# =====================================================================

# ---------------------------------------------------------------------
# execute_program <file> [arguments...]
#   The "smart" function: checks the file, finds its type and picks the
#   right way to run it.  This is the function Pakhi will call.
# ---------------------------------------------------------------------
execute_program() {
    local file="$1"
    shift

    validate_file "$file" || return $?

    case "$file" in
        *.c)
            print_info "Detected type: C source file"
            run_c "$file" "$@"
            ;;
        *.sh)
            print_info "Detected type: Shell script"
            run_shell "$file" "$@"
            ;;
        *)
            if [[ -x "$file" ]]; then
                print_info "Detected type: Executable file"
                run_executable "$file" "$@"
            else
                print_err "Unsupported file type: '$file'"
                print_info "Supported: .c files, .sh files, or executable files."
                return 1
            fi
            ;;
    esac
}

# =====================================================================
#  C. UNIX SYSTEM UTILITIES
# =====================================================================

# ---------------------------------------------------------------------
# show_system_info : pwd, date, whoami and a few extras
# ---------------------------------------------------------------------
show_system_info() {
    echo "------------- SYSTEM INFORMATION -------------"
    echo "Current directory : $(pwd)"
    echo "Date & time       : $(date '+%A, %d %B %Y  %H:%M:%S')"
    echo "Current user      : $(whoami)"
    echo "Hostname          : $(hostname 2>/dev/null)"
    echo "Operating system  : $(uname -sr)"
    echo "Bash version      : ${BASH_VERSION}"
    if command -v gcc >/dev/null 2>&1; then
        echo "GCC version       : $(gcc --version | head -n 1)"
    else
        echo "GCC version       : NOT INSTALLED"
    fi
    echo "----------------------------------------------"
}

# ---------------------------------------------------------------------
# show_permissions <file>
#   Shows the permissions of a file.
# change_permissions <file> <mode>
#   Changes permissions using chmod (e.g. 755, u+x, a-w).
# ---------------------------------------------------------------------
show_permissions() {
    local file="$1"

    if [[ -z "$file" ]]; then
        print_err "No filename given."
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        print_err "File not found: '$file'"
        return 2
    fi

    echo "Permissions of '$file':"
    ls -ld -- "$file"
    echo "Octal / symbolic : $(stat -c '%a  (%A)' -- "$file")"
    echo "Owner : $(stat -c '%U' -- "$file")   Group : $(stat -c '%G' -- "$file")"
}

change_permissions() {
    local file="$1"
    local mode="$2"

    if [[ -z "$file" || -z "$mode" ]]; then
        print_err "Usage: change_permissions <file> <mode>   e.g. 755 or u+x"
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        print_err "File not found: '$file'"
        return 2
    fi
    # Only allow safe-looking modes: 755, 0644, u+x, go-w, a=r ...
    if [[ ! "$mode" =~ ^[0-7]{3,4}$ && ! "$mode" =~ ^[ugoa]*[-+=][rwxX]+$ ]]; then
        print_err "Invalid mode '$mode'. Use something like 755 or u+x."
        return 1
    fi

    if chmod -- "$mode" "$file" 2>/dev/null; then
        print_ok "Permissions changed (mode $mode)."
        show_permissions "$file"
    else
        print_err "Permission denied: cannot change permissions of '$file'."
        print_info "Only the owner of the file (or root) can use chmod on it."
        return 3
    fi
}

# ---------------------------------------------------------------------
# show_processes [all]
#   Shows your running processes. With the word "all" shows every
#   process on the system.
# ---------------------------------------------------------------------
show_processes() {
    if ! command -v ps >/dev/null 2>&1; then
        print_err "'ps' command not found."
        return 4
    fi

    if [[ "$1" == "all" ]]; then
        echo "------------- ALL RUNNING PROCESSES -------------"
        ps -ef
    else
        echo "------------- PROCESSES OF USER: $(whoami) -------------"
        ps -u "$(whoami)" -o pid,ppid,stat,etime,comm
    fi
}

# =====================================================================
#  STANDALONE MODE (menu + command line)
#  Everything below runs only when the file is executed directly,
#  NOT when it is sourced by the main TARK script.
# =====================================================================

exec_usage() {
    cat <<'EOF'
Usage: ./execution.sh <command> [arguments]

  compile <file.c> [name]   Compile a C program with gcc
  runc    <file.c> [args]   Compile and run a C program
  runsh   <file.sh> [args]  Run a shell script with bash
  runexe  <file> [args]     Run an existing executable
  run     <file> [args]     Auto-detect type and run (recommended)
  info                      Show pwd, date, user, versions
  perms   <file>            Show file permissions
  chmod   <file> <mode>     Change permissions (e.g. 755, u+x)
  ps      [all]             Show running processes
  help                      Show this help

Run with no arguments to open the interactive menu.
EOF
}

exec_menu() {
    local choice file mode
    while true; do
        echo
        echo "======== TARK : Execution & System Utilities ========"
        echo " 1) Compile a C program"
        echo " 2) Compile and run a C program"
        echo " 3) Run a shell script"
        echo " 4) Run an existing executable"
        echo " 5) Smart run (auto-detect file type)"
        echo " 6) System information"
        echo " 7) Show file permissions"
        echo " 8) Change file permissions (chmod)"
        echo " 9) Show running processes"
        echo " 0) Exit"
        read -r -p "Enter choice: " choice
        case "$choice" in
            1) read -r -p "C file name: " file; compile_c "$file" ;;
            2) read -r -p "C file name: " file; run_c "$file" ;;
            3) read -r -p "Shell script name: " file; run_shell "$file" ;;
            4) read -r -p "Executable name: " file; run_executable "$file" ;;
            5) read -r -p "File name: " file; execute_program "$file" ;;
            6) show_system_info ;;
            7) read -r -p "File name: " file; show_permissions "$file" ;;
            8) read -r -p "File name: " file
               read -r -p "Mode (e.g. 755 or u+x): " mode
               change_permissions "$file" "$mode" ;;
            9) show_processes ;;
            0) echo "Goodbye!"; break ;;
            *) print_err "Invalid choice. Enter a number from 0 to 9." ;;
        esac
    done
}

exec_main() {
    local cmd="$1"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        compile) compile_c "$@" ;;
        runc)    run_c "$@" ;;
        runsh)   run_shell "$@" ;;
        runexe)  run_executable "$@" ;;
        run)     execute_program "$@" ;;
        info)    show_system_info ;;
        perms)   show_permissions "$@" ;;
        chmod)   change_permissions "$@" ;;
        ps)      show_processes "$@" ;;
        help|-h|--help) exec_usage ;;
        "")      exec_menu ;;
        *)       print_err "Unknown command: '$cmd'"; exec_usage; return 1 ;;
    esac
}

# Run exec_main ONLY if this file was executed directly (not sourced).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    exec_main "$@"
    exit $?
fi
