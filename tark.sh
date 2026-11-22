#!/usr/bin/env bash
# =============================================================================
# TARK - Unix-Based Mini IDE
# Module  : Main CLI and Command System   (the "brain" that joins all modules)
# File    : tark.sh
#
# WHAT IT DOES
#   1) Shows a banner and a numbered menu (same as the project flowchart).
#   2) Reads what the user types (a number OR a command like: create hello.c).
#   3) Understands the command (parsing) and calls the right function.
#   4) Loads every module found in the  modules/  folder automatically.
#
# HOW TO RUN
#   chmod +x tark.sh
#   ./tark.sh                  start the IDE
#   ./tark.sh -c "ls"          run one command and exit
#   ./tark.sh --help           show usage
#
# NOTE: all user files live in the  workspace/  folder, so nothing outside it
#       can be changed or deleted by mistake.
# =============================================================================

# --- Needs Bash (not plain sh) ------------------------------------------------
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: please run with Bash:  bash tark.sh" >&2
    exit 1
fi

TARK_VERSION="1.1"
TARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARK_WORKSPACE="${TARK_WORKSPACE:-$TARK_DIR/workspace}"
export TARK_DIR TARK_WORKSPACE

CURRENT_FILE=""     # the file we are working on right now
QUIT=0              # becomes 1 when the user wants to leave
ARGS=()             # the parsed words of the last command

# -----------------------------------------------------------------------------
# Colours (only when printing to a real terminal)
# -----------------------------------------------------------------------------
if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
    C_RED=$'\e[31m';  C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

_cli_ok()   { echo "${C_GREEN}✔ $*${C_RESET}"; }
_cli_info() { echo "${C_CYAN}ℹ $*${C_RESET}"; }
_cli_warn() { echo "${C_YELLOW}! $*${C_RESET}"; }
_cli_err()  { echo "${C_RED}✘ $*${C_RESET}" >&2; }

# -----------------------------------------------------------------------------
# Load modules: every  modules/*.sh  file is loaded automatically.
# -----------------------------------------------------------------------------
LOADED_MODULES=()
_cli_load_modules() {
    local f
    for f in "$TARK_DIR"/modules/*.sh; do
        [[ -f "$f" ]] || continue
        # shellcheck disable=SC1090
        if source "$f"; then
            LOADED_MODULES+=("$(basename "$f")")
        else
            _cli_warn "Could not load module $(basename "$f")"
        fi
    done
}

# Does a function exist?  (used to check if a teammate's module is installed)
_cli_has() { declare -F "$1" >/dev/null 2>&1; }

# Call a module function, or explain politely that the module is missing.
#   _cli_call <function> <what-it-is> [arguments...]
_cli_call() {
    local fn="$1" label="$2"; shift 2
    if _cli_has "$fn"; then
        "$fn" "$@"
    else
        _cli_warn "$label module is not installed yet."
        _cli_info "(It needs a function called '$fn' inside a file in modules/)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Input checks
# -----------------------------------------------------------------------------
# A safe file name: not empty, not absolute, no '..'  (stays inside workspace)
_cli_valid_name() {
    local n="${1:-}"
    if [[ -z "$n" ]]; then _cli_err "File name is empty."; return 1; fi
    if [[ "$n" == /* || "$n" == *..* ]]; then
        _cli_err "Please use a simple name inside the workspace (no '/' at start, no '..')."
        return 1
    fi
    return 0
}

# Make sure we have a file to work on (given or current)
_cli_need_file() {
    if [[ -z "${1:-}" ]]; then
        _cli_err "No file selected. Use 'open <file>' first, or give a file name."
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# PARSER: splits a line into words. Quotes keep words together, so
#         create "my file.c"   is ONE name:  my file.c
# Result is stored in the ARGS array.
# -----------------------------------------------------------------------------
_cli_parse() {
    local line="$1" i ch cur="" quote="" have=0
    ARGS=()
    for (( i = 0; i < ${#line}; i++ )); do
        ch="${line:i:1}"
        if [[ -n "$quote" ]]; then
            if [[ "$ch" == "$quote" ]]; then quote=""; else cur+="$ch"; fi
        else
            case "$ch" in
                '"'|"'") quote="$ch"; have=1 ;;
                ' '|$'\t')
                    if (( have )); then ARGS+=("$cur"); cur=""; have=0; fi ;;
                *) cur+="$ch"; have=1 ;;
            esac
        fi
    done
    if [[ -n "$quote" ]]; then
        _cli_err "Missing closing quote ($quote) in your command."
        return 1
    fi
    if (( have )); then ARGS+=("$cur"); fi
    return 0
}

# -----------------------------------------------------------------------------
# FILE COMMANDS:  create  open  edit  save  delete  ls
# -----------------------------------------------------------------------------
cmd_create() {
    local f="${1:-}"
    _cli_valid_name "$f" || return 1
    if [[ -e "$f" ]]; then _cli_err "'$f' already exists. Use 'open $f' instead."; return 1; fi
    mkdir -p "$(dirname "$f")" 2>/dev/null || { _cli_err "Cannot create folder for '$f'."; return 1; }
    # Create an empty file so users can write their own code.
    : > "$f" || { _cli_err "Could not create '$f'."; return 1; }
    _cli_ok "Created empty file '$f'."
    CURRENT_FILE="$f"
    _cli_info "'$f' is now the current file."
}

cmd_open() {
    local f="${1:-}"
    _cli_valid_name "$f" || return 1
    if [[ -d "$f" ]]; then _cli_err "'$f' is a folder, not a file."; return 1; fi
    if [[ ! -f "$f" ]]; then _cli_err "File '$f' does not exist. Use 'create $f' to make it."; return 1; fi
    CURRENT_FILE="$f"
    _cli_ok "Opened '$f'  (now the current file)"
    if [[ -s "$f" ]]; then
        echo "${C_DIM}-------------------------------------${C_RESET}"
        cat -n -- "$f"
        echo "${C_DIM}-------------------------------------${C_RESET}"
    else
        _cli_info "(file is empty)"
    fi
}

# Simple built-in editor, used only when nano/vim are not installed.
_cli_builtin_edit() {
    local f="$1" tmp line
    tmp="$(mktemp)" || { _cli_err "Cannot make a temporary file."; return 1; }
    _cli_info "Built-in editor. New lines are ADDED at the end of '$f'."
    if [[ -s "$f" ]]; then cat -n -- "$f"; fi
    _cli_info "Type your lines.  :wq = save and quit   :q = quit without saving"
    while IFS= read -r -p "  + " line; do
        case "$line" in
            ":wq")
                # add a newline first if the file does not end with one
                if [[ -s "$f" && -n "$(tail -c1 -- "$f")" ]]; then echo >> "$f"; fi
                cat -- "$tmp" >> "$f"
                rm -f -- "$tmp"
                _cli_ok "Saved '$f'."
                return 0 ;;
            ":q")
                rm -f -- "$tmp"; _cli_info "Nothing saved."; return 0 ;;
        esac
        printf '%s\n' "$line" >> "$tmp"
    done
    rm -f -- "$tmp"
    _cli_warn "Input ended. Nothing saved."
}

cmd_edit() {
    local f="${1:-$CURRENT_FILE}" ed="" e
    _cli_need_file "$f" || return 1
    _cli_valid_name "$f" || return 1
    if [[ ! -f "$f" ]]; then _cli_err "File '$f' does not exist. Use 'create $f' first."; return 1; fi
    CURRENT_FILE="$f"
    for e in "${EDITOR:-}" nano vim vi; do
        if [[ -n "$e" ]] && command -v "$e" >/dev/null 2>&1; then ed="$e"; break; fi
    done
    if [[ -n "$ed" && -t 0 ]]; then
        "$ed" "$f"
        _cli_ok "Closed editor for '$f'."
    else
        _cli_builtin_edit "$f"
    fi
}

# save            -> makes a safe backup copy of the current file
# save newname    -> "Save As": copies the current file to a new name
cmd_save() {
    local new="${1:-}"
    _cli_need_file "$CURRENT_FILE" || return 1
    if [[ ! -f "$CURRENT_FILE" ]]; then _cli_err "Current file no longer exists."; return 1; fi
    if [[ -n "$new" ]]; then
        _cli_valid_name "$new" || return 1
        if [[ -e "$new" ]]; then _cli_err "'$new' already exists. Choose another name."; return 1; fi
        mkdir -p "$(dirname "$new")" 2>/dev/null
        cp -- "$CURRENT_FILE" "$new" || { _cli_err "Could not save as '$new'."; return 1; }
        _cli_ok "Saved a copy as '$new'."
    else
        local dir=".tark_backup" stamp
        stamp="$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$dir"
        cp -- "$CURRENT_FILE" "$dir/$(basename "$CURRENT_FILE").$stamp" \
            || { _cli_err "Backup failed."; return 1; }
        _cli_ok "'$CURRENT_FILE' is saved. Backup kept in $dir/"
    fi
}

cmd_delete() {
    local f="${1:-}" answer=""
    _cli_valid_name "$f" || return 1
    if [[ ! -e "$f" ]]; then _cli_err "'$f' does not exist."; return 1; fi
    if [[ -d "$f" ]]; then _cli_err "'$f' is a folder. Only files can be deleted here."; return 1; fi
    read -r -p "Delete '$f' for ever? (y/N): " answer
    if [[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]]; then
        rm -f -- "$f" && _cli_ok "Deleted '$f'."
        if [[ "$CURRENT_FILE" == "$f" ]]; then CURRENT_FILE=""; fi
    else
        _cli_info "Cancelled. Nothing was deleted."
    fi
}

cmd_ls() {
    local out
    out="$(ls -1p 2>/dev/null)"
    if [[ -z "$out" ]]; then
        _cli_info "Workspace is empty. Try:  create hello.c"
    else
        echo "${C_BOLD}Files in workspace:${C_RESET}"
        while IFS= read -r f; do
            if [[ "$f" == "$CURRENT_FILE" ]]; then echo "  ${C_GREEN}▶ $f${C_RESET}"; else echo "    $f"; fi
        done <<< "$out"
    fi
}

# -----------------------------------------------------------------------------
# UNIX COMMANDS (these call the Search & Utilities module)
# -----------------------------------------------------------------------------
cmd_search() {           # search <word> [file] [-i]
    local a word="" file="" opt=()
    for a in "$@"; do
        if   [[ "$a" == "-i" ]]; then opt=(-i)
        elif [[ -z "$word" ]]; then word="$a"
        elif [[ -z "$file" ]]; then file="$a"
        fi
    done
    file="${file:-$CURRENT_FILE}"
    if [[ -z "$word" ]]; then _cli_err "Usage: search <word> [file] [-i]"; return 1; fi
    _cli_need_file "$file" || return 1
    _cli_call search_text "Search" "$word" "$file" "${opt[@]}"
}

cmd_find() {             # find <pattern> [folder]
    if [[ -z "${1:-}" ]]; then _cli_err "Usage: find <pattern> [folder]   e.g. find \"*.c\""; return 1; fi
    _cli_call find_files "Search" "$1" "${2:-.}"
}

cmd_count() {            # count [file]
    local f="${1:-$CURRENT_FILE}"
    _cli_need_file "$f" || return 1
    _cli_call count_content "Utilities" "$f"
}

cmd_sort() {             # sort [file] [-r]
    local a file="" opt=()
    for a in "$@"; do
        if [[ "$a" == "-r" ]]; then opt=(-r); else file="$a"; fi
    done
    file="${file:-$CURRENT_FILE}"
    _cli_need_file "$file" || return 1
    _cli_call sort_content "Utilities" "$file" "${opt[@]}"
}

cmd_head_tail() {        # head|tail [file] [n]
    local kind="$1"; shift
    local file n=""
    if (( $# == 1 )) && [[ "$1" =~ ^[0-9]+$ ]] && [[ -n "$CURRENT_FILE" ]]; then
        file="$CURRENT_FILE"; n="$1"          # e.g.  head 5
    else
        file="${1:-$CURRENT_FILE}"; n="${2:-}"
    fi
    _cli_need_file "$file" || return 1
    if [[ -n "$n" ]]; then _cli_call "show_$kind" "Utilities" "$file" "$n"
    else                   _cli_call "show_$kind" "Utilities" "$file"; fi
}

cmd_show() {             # show [file]
    local f="${1:-$CURRENT_FILE}"
    _cli_need_file "$f" || return 1
    _cli_call display_file "Utilities" "$f"
}

# Run ANY Unix command:   !ls -l     or    unix who
cmd_unix() {
    local raw="$1"
    if [[ -z "${raw// }" ]]; then _cli_err "Usage: !<unix command>   e.g. !ls -l"; return 1; fi
    bash -c "$raw"
    local rc=$?
    if (( rc != 0 )); then _cli_warn "Command finished with exit code $rc."; fi
    return $rc
}

# -----------------------------------------------------------------------------
# HOOKS for the other team members' modules.
# Each one calls a function the teammate must define in modules/<their>.sh
# -----------------------------------------------------------------------------
cmd_compile() { local f="${1:-$CURRENT_FILE}"; _cli_need_file "$f" || return 1; _cli_call tark_compile "Compile" "$f"; }
cmd_run()     { local f="${1:-$CURRENT_FILE}"; _cli_need_file "$f" || return 1; [[ $# -gt 0 ]] && shift; _cli_call tark_run "Run" "$f" "$@"; }
cmd_process() { _cli_call tark_process "Process management" "$@"; }
cmd_pipes()   { _cli_call tark_pipes   "Pipes & redirection" "$@"; }
cmd_make()    { _cli_call tark_make    "Makefile project" "$@"; }
cmd_report()  { _cli_call tark_report  "Build & test report" "$@"; }

# -----------------------------------------------------------------------------
# Screens: banner, menu, help, status
# -----------------------------------------------------------------------------
show_banner() {
    echo "${C_CYAN}${C_BOLD}"
    cat <<'ART'
  ╔════════════════════════════════════════════╗
  ║                                            ║
  ║     T A R K   -   Unix Based Mini IDE      ║
  ║                                            ║
  ╚════════════════════════════════════════════╝
ART
    echo "${C_RESET}${C_DIM}  Version $TARK_VERSION   |   type 'help' for commands${C_RESET}"
}

show_menu() {
    echo
    echo "${C_BOLD}  MAIN MENU${C_RESET}   ${C_DIM}(type a number or a command)${C_RESET}"
    echo "  ${C_BLUE}1${C_RESET}  File Management       create / open / edit / save / delete"
    echo "  ${C_BLUE}2${C_RESET}  Unix Commands         search / find / count / sort / head / tail"
    echo "  ${C_BLUE}3${C_RESET}  Compile & Run         compile and run the current C file"
    echo "  ${C_BLUE}4${C_RESET}  Process Management    process [run \"command\"]"
    echo "  ${C_BLUE}5${C_RESET}  Pipes & Redirection"
    echo "  ${C_BLUE}6${C_RESET}  Multi-file Project    (Makefile)"
    echo "  ${C_BLUE}7${C_RESET}  Build & Test Report"
    echo "  ${C_BLUE}0${C_RESET}  Exit"
}

show_help() {
    local topic="${1:-all}"
    if [[ "$topic" == "all" || "$topic" == "files" ]]; then
        echo "${C_BOLD}FILE COMMANDS${C_RESET}"
        echo "  create <file>       make a new file (a .c file gets starter code)"
        echo "  open <file>         open a file and show it with line numbers"
        echo "  edit [file]         edit the file (nano/vim, or the built-in editor)"
        echo "  save [newname]      save a backup copy, or 'save as' a new name"
        echo "  delete <file>       delete a file (asks first)"
        echo "  ls                  list files in the workspace"
        echo "  filemenu            open the dedicated file-management submenu"
        echo "  show [file]         print the whole file"
    fi
    if [[ "$topic" == "all" || "$topic" == "unix" ]]; then
        echo "${C_BOLD}UNIX COMMANDS${C_RESET}"
        echo "  search <word> [file] [-i]   find a word inside a file (-i ignores case)"
        echo "  find <pattern> [folder]     find files by name, e.g. find \"*.c\""
        echo "  count [file]                count lines, words, characters"
        echo "  sort [file] [-r]            show the file sorted (-r = reverse)"
        echo "  head [file] [n]             first n lines (default 10)"
        echo "  tail [file] [n]             last n lines (default 10)"
        echo "  !<command>                  run any Unix command, e.g.  !ls -l  or  !date"
    fi
    if [[ "$topic" == "all" ]]; then
        echo "${C_BOLD}BUILD & SYSTEM${C_RESET}"
        echo "  compile [file]   compile a C program      run [file]   run it"
        echo "  process [run \"command\"]  list processes or create/wait for a child"
        echo "  pipes pipe \"cmd1\" \"cmd2\"   connect commands; input/output/append redirect"
        echo "  make init        scaffold a multi-file project; make [target] builds it"
        echo "  make test        run project tests           report       show last build/test report"
        echo "${C_BOLD}OTHER${C_RESET}"
        echo "  menu   show the main menu     status   show current file and modules"
        echo "  clear  clear the screen       help     this help     exit / quit   leave"
        echo
        echo "${C_DIM}Tip: if a name has spaces, use quotes:  create \"my file.c\"${C_RESET}"
    fi
}

cmd_status() {
    echo "${C_BOLD}STATUS${C_RESET}"
    echo "  Workspace    : $TARK_WORKSPACE"
    echo "  Current file : ${CURRENT_FILE:-(none)}"
    echo "  Modules      : ${LOADED_MODULES[*]:-(none)}"
    local fn label
    for fn in tark_compile:Compile tark_run:Run tark_process:Process tark_pipes:Pipes tark_make:Makefile tark_report:Report; do
        label="${fn#*:}"; fn="${fn%%:*}"
        if _cli_has "$fn"; then echo "    ${C_GREEN}✔${C_RESET} $label ready"
        else                    echo "    ${C_DIM}○ $label not installed yet${C_RESET}"; fi
    done
}

# -----------------------------------------------------------------------------
# DISPATCH: decides which function to run for a line of input
# -----------------------------------------------------------------------------
dispatch() {
    local line="$1" cmd

    # "!ls -l"  -> run a Unix command exactly as typed
    if [[ "$line" == '!'* ]]; then cmd_unix "${line:1}"; return; fi

    _cli_parse "$line" || return 1
    (( ${#ARGS[@]} )) || return 0
    cmd="${ARGS[0],,}"                       # command word in lower case
    local rest=("${ARGS[@]:1}")

    case "$cmd" in
        # --- menu numbers ---------------------------------------------------
        0) QUIT=1 ;;
        1) show_help files ;;
        2) show_help unix ;;
        3) cmd_compile && cmd_run ;;
        4) cmd_process ;;
        5) cmd_pipes ;;
        6) cmd_make ;;
        7) cmd_report ;;
        # --- files ----------------------------------------------------------
        create|new|touch) cmd_create "${rest[0]:-}" ;;
        open)             cmd_open   "${rest[0]:-}" ;;
        edit)             cmd_edit   "${rest[0]:-}" ;;
        save)             cmd_save   "${rest[0]:-}" ;;
        delete|rm|del)    cmd_delete "${rest[0]:-}" ;;
        ls|list|files)    cmd_ls ;;
        filemenu|fm)      _cli_call file_management "File management" ;;
        show|cat|display) cmd_show   "${rest[0]:-}" ;;
        # --- unix -----------------------------------------------------------
        search|grep)      cmd_search "${rest[@]}" ;;
        find)             cmd_find   "${rest[@]}" ;;
        count|wc)         cmd_count  "${rest[0]:-}" ;;
        sort)             cmd_sort   "${rest[@]}" ;;
        head)             cmd_head_tail head "${rest[@]}" ;;
        tail)             cmd_head_tail tail "${rest[@]}" ;;
        unix|sh|shell)    cmd_unix "${line#* }" ;;
        # --- build & system (teammates' modules) ----------------------------
        compile|build)    cmd_compile "${rest[0]:-}" ;;
        run|execute)      cmd_run "${rest[@]}" ;;
        process|processes|ps) cmd_process "${rest[@]}" ;;
        sysinfo)          _cli_call show_system_info "System information" ;;
        perms)            _cli_call show_permissions "Permissions" "${rest[0]:-}" ;;
        chmod)            _cli_call change_permissions "Permissions" "${rest[0]:-}" "${rest[1]:-}" ;;
        pipes|pipe|redirect)  cmd_pipes "${rest[@]}" ;;
        make|makefile|project) cmd_make "${rest[@]}" ;;
        report|test)      cmd_report "${rest[@]}" ;;
        # --- other ----------------------------------------------------------
        help|h|\?)        show_help "${rest[0]:-all}" ;;
        menu|m)           show_menu ;;
        status|info)      cmd_status ;;
        clear|cls)        clear ;;
        exit|quit|q|bye)  QUIT=1 ;;
        *)
            _cli_err "Unknown command '${ARGS[0]}'. Type 'help' to see all commands."
            return 1 ;;
    esac
}

# -----------------------------------------------------------------------------
# MAIN LOOP
# -----------------------------------------------------------------------------
main_loop() {
    local line prompt
    while (( ! QUIT )); do
        prompt="${C_GREEN}${C_BOLD}tark${C_RESET}"
        if [[ -n "$CURRENT_FILE" ]]; then prompt+=" ${C_YELLOW}[$CURRENT_FILE]${C_RESET}"; fi
        prompt+="${C_GREEN}${C_BOLD} ❯ ${C_RESET}"

        if [[ -t 0 ]]; then
            # arrow keys and history work only on a real terminal
            if ! IFS= read -r -e -p "$prompt" line; then echo; break; fi
            [[ -n "$line" ]] && history -s -- "$line"
        else
            printf '%s' "$prompt"
            if ! IFS= read -r line; then echo; break; fi
            echo "$line"
        fi

        # trim spaces at both ends
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue

        dispatch "$line"
    done
    echo "${C_CYAN}Goodbye! Thank you for using TARK.${C_RESET}"
}

# -----------------------------------------------------------------------------
# START
# -----------------------------------------------------------------------------
_cli_usage() {
    cat <<EOF
TARK - Unix Based Mini IDE  (version $TARK_VERSION)
Usage:
  ./tark.sh                start the IDE
  ./tark.sh -c "command"   run one command and exit   (e.g. -c "ls")
  ./tark.sh --help         show this message
  ./tark.sh --version      show the version
EOF
}

main() {
    case "${1:-}" in
        -h|--help)    _cli_usage; return 0 ;;
        -v|--version) echo "TARK $TARK_VERSION"; return 0 ;;
    esac

    mkdir -p "$TARK_WORKSPACE" 2>/dev/null || { _cli_err "Cannot create workspace '$TARK_WORKSPACE'."; return 1; }
    cd "$TARK_WORKSPACE" || { _cli_err "Cannot enter workspace."; return 1; }
    _cli_load_modules

    if [[ "${1:-}" == "-c" ]]; then
        if [[ -z "${2:-}" ]]; then _cli_err "Usage: ./tark.sh -c \"command\""; return 1; fi
        dispatch "$2"
        return $?
    fi

    show_banner
    show_menu
    echo
    main_loop
}

# Run only when executed directly (not when sourced by a test)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
