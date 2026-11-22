#!/usr/bin/env bash
# =============================================================================
# TARK - Unix-Based Mini IDE
# Module  : Search and Unix Utilities  (Part 1 of 2: SEARCH)
# File    : search.sh
# Purpose : Functions to search for text inside files and to find files by name.
#
# HOW TO USE
#   1) Load it into your shell or another script:   source ./search.sh
#   2) Call a function:                              search_text "main" "app.c"
#   Or run a function directly from the terminal:
#        ./search.sh search_text "main" "app.c" -i
#
# RETURN CODES (used by every function in this file)
#   0 = success (something was found / shown)
#   1 = bad input or error (missing file, empty input, invalid directory ...)
#   2 = valid input, but nothing matched
#
# NOTE: This file never uses "set -e" or "exit" while being sourced, so it can
#       never close the shell of whoever imports it.
# =============================================================================

# --- Safety check: this file needs Bash (not plain sh). Uses POSIX syntax on purpose. ---
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: please use Bash:  bash $0   (or: source this file from Bash)" >&2
    return 1 2>/dev/null || exit 1
fi


# -----------------------------------------------------------------------------
# _search_check_file  (private helper)
# Checks that the given path is a usable, readable, regular file.
# Usage  : _search_check_file "path/to/file"
# Returns: 0 if the file is fine, 1 (and prints an error) otherwise.
# -----------------------------------------------------------------------------
_search_check_file() {
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
# search_text
# Searches for a word/phrase inside ONE file using grep and prints every
# matching line together with its line number (format  LINE_NUMBER:TEXT).
#
# Usage  : search_text "word" "file" [-i]
#            word  - text to look for (treated literally, not as a regex)
#            file  - file to search in (spaces in the name are fine)
#            -i    - optional: ignore upper/lower case
#                    (also accepted: i, y, yes)
# Example: search_text "hello" "my notes.txt" -i
# Uses   : grep -n  (show line numbers)
#          grep -F  (fixed string, so characters like [ . * are not special)
#          grep -i  (case-insensitive, only when asked)
# -----------------------------------------------------------------------------
search_text() {
    local word="${1:-}"
    local file="${2:-}"
    local ignore_case="${3:-}"
    local -a options=(-n -F)        # an array keeps every option separate and safe
    local result count

    # --- validate input ---
    if [[ -z "$word" ]]; then
        echo "Error: search word is empty." >&2
        return 1
    fi
    _search_check_file "$file" || return 1

    # --- turn on case-insensitive mode if requested ---
    case "${ignore_case,,}" in      # ${var,,} converts the value to lowercase
        -i|i|y|yes) options+=(-i) ;;
    esac

    # --- run grep; "--" means "no more options", so a word like -x is safe ---
    if result=$(grep "${options[@]}" -- "$word" "$file"); then
        count=$(printf '%s\n' "$result" | wc -l)
        echo "Matches for '$word' in '$file':"
        printf '%s\n' "$result"
        echo "Total matching lines: $count"
        return 0
    fi

    echo "No matches found for '$word' in '$file'."
    return 2
}


# -----------------------------------------------------------------------------
# find_files
# Finds regular files by NAME inside a directory (and all its sub-directories)
# using the find command.
#
# Usage  : find_files "pattern" ["directory"]
#            pattern   - file name or wildcard pattern, e.g. "*.txt" or "notes.txt"
#                        If it has NO wildcard (* ? [ ]), it is treated as part
#                        of the name, so "report" finds "my report.txt" too.
#            directory - where to start searching (default: current directory ".")
# Example: find_files "*.sh" "$HOME/project"
# Uses   : find DIR -type f -name PATTERN
# -----------------------------------------------------------------------------
find_files() {
    local pattern="${1:-}"
    local dir="${2:-.}"             # default to the current directory
    local results count

    # --- validate input ---
    if [[ -z "$pattern" ]]; then
        echo "Error: file name pattern is empty." >&2
        return 1
    fi
    if [[ ! -e "$dir" ]]; then
        echo "Error: directory '$dir' does not exist." >&2
        return 1
    fi
    if [[ ! -d "$dir" ]]; then
        echo "Error: '$dir' is not a directory." >&2
        return 1
    fi
    if [[ ! -r "$dir" || ! -x "$dir" ]]; then
        echo "Error: no permission to search inside '$dir'." >&2
        return 1
    fi

    # --- no wildcard typed? then search for the text anywhere in the name ---
    if [[ "$pattern" != *[\*\?\[]* ]]; then
        pattern="*${pattern}*"
    fi

    # --- run find; unreadable sub-folders are silently skipped (2>/dev/null) ---
    results=$(find "$dir" -type f -name "$pattern" 2>/dev/null | sort)

    if [[ -z "$results" ]]; then
        echo "No files matching '$pattern' found in '$dir'."
        return 2
    fi

    count=$(printf '%s\n' "$results" | wc -l)
    echo "Files matching '$pattern' in '$dir':"
    printf '%s\n' "$results"
    echo "Total files found: $count"
    return 0
}


# -----------------------------------------------------------------------------
# Direct-run support: lets you test a function without writing a script.
#   ./search.sh search_text "word" "file" -i
# This block is skipped completely when the file is imported with "source".
# -----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        search_text|find_files)
            "$@"                    # run the chosen function with its arguments
            exit $?
            ;;
        *)
            echo "Usage: $0 search_text \"word\" \"file\" [-i]"
            echo "       $0 find_files \"pattern\" [\"directory\"]"
            exit 1
            ;;
    esac
fi
