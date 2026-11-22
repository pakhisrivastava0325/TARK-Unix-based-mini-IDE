#!/usr/bin/env bash
# =============================================================================
#  TARK - UNIX-Based Mini IDE
#  Module  : File Editor & File Management
#  File    : file_management.sh
#
#  USAGE
#    Standalone : ./file_management.sh        (opens the submenu directly)
#    Integrated : source modules/file_management.sh   (only loads functions)
#                 file_management                     (then call it)
#
#  NOTE: Sourcing this file does NOT start the menu. The menu starts only
#        when the main script calls file_management(), or when this file
#        is executed directly.
# =============================================================================

# Directory in which all files are created/edited/deleted.
# The main TARK script can override it:  export TARK_WORKSPACE="/path/to/dir"
FM_WORKSPACE="${TARK_WORKSPACE:-$HOME/TARK_Workspace}"

# Global variable used to pass a validated filename between functions.
FM_NAME=""

# -----------------------------------------------------------------------------
# Small helper functions
# -----------------------------------------------------------------------------

# Print an error message in a uniform format.
fm_error() { echo "[ERROR] $*" >&2; }

# Print an information / success message.
fm_ok()    { echo "[OK] $*"; }

# Pause so the user can read the output before the menu is redrawn.
fm_pause() {
    echo
    read -r -p "Press Enter to continue..." _
}

# Clear the screen only when running in a real terminal.
fm_clear() {
    if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
        clear
    fi
    return 0
}

# Ask a yes/no question. Returns 0 only for y / Y / yes / YES.
fm_confirm() {
    local answer
    read -r -p "$1 (y/N): " answer || return 1
    case "$answer" in
        y|Y|yes|YES|Yes) return 0 ;;
        *)               return 1 ;;
    esac
}

# Create the workspace directory if needed and make sure it is usable.
fm_init_workspace() {
    if [[ ! -d "$FM_WORKSPACE" ]]; then
        mkdir -p -- "$FM_WORKSPACE" 2>/dev/null || {
            fm_error "Cannot create workspace: $FM_WORKSPACE"
            return 1
        }
    fi
    if [[ ! -w "$FM_WORKSPACE" || ! -x "$FM_WORKSPACE" ]]; then
        fm_error "No permission to use workspace: $FM_WORKSPACE"
        return 1
    fi
    return 0
}

# Validate a filename. Spaces are allowed (we always quote variables).
# Returns 0 if valid, 1 (after printing the reason) if invalid.
fm_validate_name() {
    local name="$1"
    local bad_chars='[\\*?"<>|:]'          # characters we refuse
    local edge_space='^[[:space:]]|[[:space:]]$'

    if [[ -z "$name" || -z "${name//[[:space:]]/}" ]]; then
        fm_error "Filename cannot be empty."; return 1
    elif [[ "$name" == "." || "$name" == ".." ]]; then
        fm_error "'$name' is not a valid filename."; return 1
    elif [[ "$name" == */* ]]; then
        fm_error "Filename cannot contain '/'. Give a name only, not a path."; return 1
    elif [[ "$name" == -* ]]; then
        fm_error "Filename cannot start with '-'."; return 1
    elif (( ${#name} > 255 )); then
        fm_error "Filename is too long (max 255 characters)."; return 1
    elif [[ "$name" =~ [[:cntrl:]] ]]; then
        fm_error "Filename contains control characters."; return 1
    elif [[ "$name" =~ $bad_chars ]]; then
        fm_error "Filename contains an invalid character (\\ * ? \" < > | :)."; return 1
    elif [[ "$name" =~ $edge_space ]]; then
        fm_error "Filename cannot start or end with a space."; return 1
    fi
    return 0
}

# Prompt for a filename and validate it. Result is stored in FM_NAME.
fm_read_filename() {
    FM_NAME=""
    read -r -p "$1" FM_NAME || return 1
    fm_validate_name "$FM_NAME" || return 1
    return 0
}

# -----------------------------------------------------------------------------
# Feature functions
# -----------------------------------------------------------------------------

# Edit helper: opens a full path in nano and reports whether it was saved.
fm_edit_path() {
    local path="$1" backup status=0

    if ! command -v nano >/dev/null 2>&1; then
        fm_error "Nano is not installed. Install it with: sudo apt install nano"
        return 1
    fi
    if [[ ! -w "$path" ]]; then
        fm_error "No write permission for '$path'."
        return 1
    fi

    # Keep a temporary copy so we can tell afterwards if anything changed.
    backup="$(mktemp)" || { fm_error "Could not create temp file."; return 1; }
    cp -p -- "$path" "$backup"

    echo "Opening Nano...  (Ctrl+O = save, Enter = confirm name, Ctrl+X = exit)"
    nano -- "$path" || status=$?

    if cmp -s -- "$backup" "$path"; then
        echo "No changes were made to '${path##*/}'."
    else
        fm_ok "Changes saved to '${path##*/}' ($(stat -c %s -- "$path") bytes, $(wc -l < "$path") lines)."
    fi
    rm -f -- "$backup"

    (( status == 0 )) || fm_error "Nano exited with status $status."
    return 0
}

# 1. CREATE a new file with touch.
fm_create_file() {
    echo "--- Create New File ---"
    fm_read_filename "Enter new filename (e.g. main.c, notes.txt, run.sh): " || return 1
    local name="$FM_NAME" path="$FM_WORKSPACE/$FM_NAME"

    # Extension is optional, but warn the user if none was typed.
    if [[ "$name" != *.* ]]; then
        fm_confirm "No extension given. Create '$name' anyway?" || {
            echo "Cancelled."; return 1; }
    fi

    if [[ -e "$path" ]]; then
        fm_error "'$name' already exists. Choose another name."
        return 1
    fi

    if touch -- "$path" 2>/dev/null; then
        fm_ok "File '$name' created in $FM_WORKSPACE"
        fm_confirm "Open it in the editor now?" && fm_edit_path "$path"
    else
        fm_error "Could not create '$name' (check permissions)."
        return 1
    fi
    return 0
}

# 2. OPEN (display) an existing file with cat.
fm_open_file() {
    echo "--- Open Existing File ---"
    fm_read_filename "Enter filename to open: " || return 1
    local name="$FM_NAME" path="$FM_WORKSPACE/$FM_NAME"

    if [[ ! -e "$path" ]]; then
        fm_error "File '$name' does not exist."; return 1
    elif [[ -d "$path" ]]; then
        fm_error "'$name' is a directory, not a file."; return 1
    elif [[ ! -r "$path" ]]; then
        fm_error "No read permission for '$name'."; return 1
    elif [[ ! -s "$path" ]]; then
        echo "('$name' is empty)"; return 0
    fi

    # Do not dump binary files onto the terminal.
    if command -v file >/dev/null 2>&1 &&
       [[ "$(file -b --mime-encoding -- "$path")" == "binary" ]]; then
        fm_error "'$name' is a binary file and cannot be displayed."
        return 1
    fi

    echo "=============== $name ==============="
    cat -n -- "$path"
    echo "=============== end of file ($(wc -l < "$path") lines) ==============="
    return 0
}

# 3 & 4. EDIT a file with nano (saving is done inside nano; we verify it).
fm_edit_file() {
    echo "--- Edit File ---"
    fm_read_filename "Enter filename to edit: " || return 1
    local name="$FM_NAME" path="$FM_WORKSPACE/$FM_NAME"

    if [[ -d "$path" ]]; then
        fm_error "'$name' is a directory, not a file."; return 1
    fi
    if [[ ! -e "$path" ]]; then
        fm_error "File '$name' does not exist."
        if fm_confirm "Create it now?"; then
            touch -- "$path" 2>/dev/null || { fm_error "Could not create '$name'."; return 1; }
        else
            return 1
        fi
    fi
    fm_edit_path "$path"
}

# 5. LIST all files and directories using ls.
fm_list_files() {
    echo "--- Files in $FM_WORKSPACE ---"
    if [[ -z "$(ls -A -- "$FM_WORKSPACE")" ]]; then
        echo "(workspace is empty)"
        return 0
    fi
    ls -lAh --group-directories-first --color=auto -- "$FM_WORKSPACE"
    echo
    echo "Total items: $(ls -A -- "$FM_WORKSPACE" | wc -l)"
}

# 6. FILE INFORMATION using stat.
fm_file_info() {
    echo "--- File Information ---"
    fm_read_filename "Enter filename: " || return 1
    local name="$FM_NAME" path="$FM_WORKSPACE/$FM_NAME"

    if [[ ! -e "$path" ]]; then
        fm_error "File '$name' does not exist."; return 1
    fi

    echo "Name         : $name"
    echo "Size         : $(stat -c '%s' -- "$path") bytes"
    echo "Type         : $(stat -c '%F' -- "$path")"
    echo "Permissions  : $(stat -c '%A (%a)' -- "$path")"
    echo "Owner:Group  : $(stat -c '%U:%G' -- "$path")"
    echo "Modified     : $(stat -c '%y' -- "$path" | cut -d. -f1)"
    if command -v file >/dev/null 2>&1; then
        echo "Content kind : $(file -b -- "$path")"
    fi
}

# 7. DELETE a file after confirmation using rm.
fm_delete_file() {
    echo "--- Delete File ---"
    fm_read_filename "Enter filename to delete: " || return 1
    local name="$FM_NAME" path="$FM_WORKSPACE/$FM_NAME"

    if [[ ! -e "$path" && ! -L "$path" ]]; then
        fm_error "File '$name' does not exist."; return 1
    elif [[ -d "$path" && ! -L "$path" ]]; then
        fm_error "'$name' is a directory. This module deletes files only."; return 1
    fi

    if fm_confirm "Permanently delete '$name'?"; then
        if rm -- "$path" 2>/dev/null; then
            fm_ok "'$name' deleted."
        else
            fm_error "Could not delete '$name' (check permissions)."
            return 1
        fi
    else
        echo "Deletion cancelled. File kept."
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Menu
# -----------------------------------------------------------------------------
fm_show_menu() {
    fm_clear
    echo "=========================================="
    echo "         TARK - FILE MANAGEMENT"
    echo "=========================================="
    echo " Workspace: $FM_WORKSPACE"
    echo "------------------------------------------"
    echo " 1. Create New File"
    echo " 2. Open Existing File"
    echo " 3. Edit File"
    echo " 4. List All Files"
    echo " 5. View File Information"
    echo " 6. Delete File"
    echo " 7. Back to Main Menu"
    echo "=========================================="
}

# ENTRY POINT - the main TARK script calls this function.
file_management() {
    fm_init_workspace || { fm_pause; return 1; }

    local choice
    while true; do
        fm_show_menu
        # If input ends (Ctrl+D), go back to the main menu instead of looping.
        read -r -p "Enter your choice [1-7]: " choice || { echo; return 0; }
        echo

        case "$choice" in
            1) fm_create_file ;;
            2) fm_open_file ;;
            3) fm_edit_file ;;
            4) fm_list_files ;;
            5) fm_file_info ;;
            6) fm_delete_file ;;
            7) echo "Returning to TARK main menu..."; return 0 ;;
            "") fm_error "No choice entered. Please type a number from 1 to 7." ;;
            *)  fm_error "Invalid choice '$choice'. Please enter a number from 1 to 7." ;;
        esac
        fm_pause
    done
}

# Run the menu ONLY when this file is executed directly (not when sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    file_management
fi
