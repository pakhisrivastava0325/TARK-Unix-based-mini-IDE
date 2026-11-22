#!/usr/bin/env bash
# =============================================================================
# TARK - Unix-Based Mini IDE
# Module  : Search and Unix Utilities  (Part 2 of 2: UTILITIES)
# File    : utilities.sh
# Purpose : Functions to count, sort, and view the contents of text files.
#
# HOW TO USE
#   1) Load it into your shell or another script:   source ./utilities.sh
#   2) Call a function:                              show_head "app.c" 5
#   Or run a function directly from the terminal:
#        ./utilities.sh count_content "my file.txt"
#
# RETURN CODES (used by every function in this file)
#   0 = success
#   1 = bad input or error (missing file, empty input, invalid number ...)
#
# NOTE: No function here ever changes the original file. They only read it.
#       This file never uses "set -e" or "exit" while being sourced.
# =============================================================================

# --- Safety check: this file needs Bash (not plain sh). Uses POSIX syntax on purpose. ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: please use Bash:  bash $0   (or: source this file from Bash)" >&2
    return 1 2>/dev/null || exit 1
fi


# -----------------------------------------------------------------------------
# _util_check_file  (private helper)
# Checks that the given path is a usable, readable, regular file.
# Usage  : _util_check_file "path/to/file"
# Returns: 0 if the file is fine, 1 (and prints an error) otherwise.
# -----------------------------------------------------------------------------
_util_check_file() {
    local file="${1:-}"

    if [[ -z "$file" ]]; then
        echo "Error: file name is empty." >&2
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        echo "Error: file '$file' does not exist." >&2
        return 1
    fi
    if [[ -d "$file" ]]; then
        echo "Error: '$file' is a directory, not a file." >&2
        return 1
    fi
    if [[ ! -f "$file" ]]; then
        echo "Error: '$file' is not a regular file." >&2
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        echo "Error: no permission to read '$file'." >&2
        return 1
    fi
    return 0
}


# -----------------------------------------------------------------------------
# _util_check_number  (private helper)
# Checks that a value is a positive whole number (1, 2, 3 ...).
# Usage  : _util_check_number "10"
# Returns: 0 if valid, 1 (and prints an error) otherwise.
# -----------------------------------------------------------------------------
_util_check_number() {
    local value="${1:-}"

    # ^[0-9]+$ means "only digits, at least one"
    if [[ ! "$value" =~ ^[0-9]+$ ]] || (( 10#$value < 1 )); then
        echo "Error: '$value' is not a valid positive number." >&2
        return 1
    fi
    return 0
}


# -----------------------------------------------------------------------------
# count_content
# Counts the lines, words and characters of a file using wc.
#
# Usage  : count_content "file"
# Example: count_content "my notes.txt"
# Uses   : wc -l (lines), wc -w (words), wc -m (characters)
#          "wc < file" feeds the file through input redirection so wc prints
#          only the number and not the file name.
# -----------------------------------------------------------------------------
count_content() {
    local file="${1:-}"
    local lines words chars

    _util_check_file "$file" || return 1

    lines=$(wc -l < "$file" | tr -d ' ')
    words=$(wc -w < "$file" | tr -d ' ')
    chars=$(wc -m < "$file" | tr -d ' ')

    echo "Statistics for '$file':"
    printf 'Lines      : %s\n' "$lines"
    printf 'Words      : %s\n' "$words"
    printf 'Characters : %s\n' "$chars"
    return 0
}


# -----------------------------------------------------------------------------
# sort_content
# Prints the lines of a file in sorted (alphabetical) order using sort.
# The ORIGINAL FILE IS NEVER CHANGED: sort only writes to the screen.
#
# Usage  : sort_content "file" [-r]
#            -r  - optional: reverse order (Z to A)
# Example: sort_content "names.txt" -r
# Uses   : sort
# -----------------------------------------------------------------------------
sort_content() {
    local file="${1:-}"
    local order="${2:-}"
    local -a options=()

    _util_check_file "$file" || return 1

    if [[ "$order" == "-r" ]]; then
        options+=(-r)
    elif [[ -n "$order" ]]; then
        echo "Error: unknown option '$order' (only -r is allowed)." >&2
        return 1
    fi

    if [[ ! -s "$file" ]]; then
        echo "(file '$file' is empty - nothing to sort)"
        return 0
    fi

    echo "Sorted content of '$file' (original file is not modified):"
    sort "${options[@]}" -- "$file"     # output goes to the screen only
    return 0
}


# -----------------------------------------------------------------------------
# show_head
# Shows the first N lines of a file (default 10) using head.
#
# Usage  : show_head "file" [number_of_lines]
# Example: show_head "log.txt"        -> first 10 lines
#          show_head "log.txt" 3      -> first 3 lines
# Uses   : head -n
# -----------------------------------------------------------------------------
show_head() {
    local file="${1:-}"
    local n="${2:-10}"              # if no number is given, use 10

    _util_check_file "$file" || return 1
    _util_check_number "$n"  || return 1

    if [[ ! -s "$file" ]]; then
        echo "(file '$file' is empty)"
        return 0
    fi

    echo "First $n line(s) of '$file':"
    head -n "$n" -- "$file"
    return 0
}


# -----------------------------------------------------------------------------
# show_tail
# Shows the last N lines of a file (default 10) using tail.
#
# Usage  : show_tail "file" [number_of_lines]
# Example: show_tail "log.txt"        -> last 10 lines
#          show_tail "log.txt" 3      -> last 3 lines
# Uses   : tail -n
# -----------------------------------------------------------------------------
show_tail() {
    local file="${1:-}"
    local n="${2:-10}"              # if no number is given, use 10

    _util_check_file "$file" || return 1
    _util_check_number "$n"  || return 1

    if [[ ! -s "$file" ]]; then
        echo "(file '$file' is empty)"
        return 0
    fi

    echo "Last $n line(s) of '$file':"
    tail -n "$n" -- "$file"
    return 0
}


# -----------------------------------------------------------------------------
# display_file
# Displays the complete contents of a file using cat.
#
# Usage  : display_file "file"
# Example: display_file "my notes.txt"
# Uses   : cat
# -----------------------------------------------------------------------------
display_file() {
    local file="${1:-}"

    _util_check_file "$file" || return 1

    if [[ ! -s "$file" ]]; then
        echo "(file '$file' is empty)"
        return 0
    fi

    echo "Contents of '$file':"
    cat -- "$file"
    return 0
}


# -----------------------------------------------------------------------------
# Direct-run support: lets you test a function without writing a script.
#   ./utilities.sh show_head "file" 5
# This block is skipped completely when the file is imported with "source".
# -----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        count_content|sort_content|show_head|show_tail|display_file)
            "$@"                    # run the chosen function with its arguments
            exit $?
            ;;
        *)
            echo "Usage: $0 count_content \"file\""
            echo "       $0 sort_content  \"file\" [-r]"
            echo "       $0 show_head     \"file\" [lines]"
            echo "       $0 show_tail     \"file\" [lines]"
            echo "       $0 display_file  \"file\""
            exit 1
            ;;
    esac
fi
