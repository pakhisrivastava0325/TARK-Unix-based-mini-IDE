#!/usr/bin/env bash
# =============================================================================
# TARK - Main CLI automated test
# Runs the IDE with typed input and checks the output.   Usage: ./test_cli.sh
# It uses a temporary workspace, so your real workspace/ is never touched.
# =============================================================================

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TARK_WORKSPACE
TARK_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TARK_WORKSPACE"' EXIT

pass=0; fail=0

# session "<lines typed by the user>"  -> prints the IDE output (no colours)
session() { printf '%b' "$1" | "$HERE/tark.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }

# check "<description>" "<typed input>" "<text that must appear>"
check() {
    local out; out="$(session "$2")"
    if grep -qF -- "$3" <<< "$out"; then
        echo "  [PASS] $1"; pass=$((pass+1))
    else
        echo "  [FAIL] $1   (expected to see: $3)"; fail=$((fail+1))
    fi
}

# check_not "<description>" "<typed input>" "<text that must NOT appear>"
check_not() {
    local out; out="$(session "$2")"
    if grep -qF -- "$3" <<< "$out"; then
        echo "  [FAIL] $1   (should not see: $3)"; fail=$((fail+1))
    else
        echo "  [PASS] $1"; pass=$((pass+1))
    fi
}

echo "== Start-up and menu =="
check "banner is shown"                 "exit\n"                       "Unix Based Mini IDE"
check "menu is shown"                   "exit\n"                       "MAIN MENU"
check "exit says goodbye"               "exit\n"                       "Goodbye"
check "quit also works"                 "quit\n"                       "Goodbye"
check "0 exits"                         "0\n"                          "Goodbye"
check "Ctrl+D (end of input) exits"     ""                             "Goodbye"
check "empty line is ignored"           "\n\n\nexit\n"                 "Goodbye"
check "unknown command is explained"    "bogus\nexit\n"                "Unknown command 'bogus'"
check "help lists commands"             "help\nexit\n"                 "FILE COMMANDS"
check "help topic works"                "help unix\nexit\n"            "search <word>"
check "menu command re-shows menu"      "menu\nexit\n"                 "Multi-file Project"
check "status shows workspace"          "status\nexit\n"               "Workspace"
check "status shows loaded modules"     "status\nexit\n"               "search.sh"

echo "== create / open =="
check "create makes an empty file and user can write code" "create a.c\nedit a.c\n#include <stdio.h>\nint main(void) {\nprintf(\"Hello, World!\");\nreturn 0;\n}\n:wq\nexit\n" "Created empty file 'a.c'"
check "create makes an empty C file"     "create b.c\nopen b.c\nexit\n" "(file is empty)"
check "create plain file is empty"      "create n.txt\nexit\n"         "Created empty file 'n.txt'"
check "create refuses duplicates"       "create a.c\ncreate a.c\nexit\n" "already exists"
check "create without name"             "create\nexit\n"               "File name is empty"
check "create blocks .. paths"          "create ../x.c\nexit\n"        "no '..'"
check "create blocks absolute paths"    "create /tmp/x.c\nexit\n"      "no '/' at start"
check "name with spaces (quotes)"       "create \"my file.c\"\nls\nexit\n" "my file.c"
check "open missing file"               "open nope.c\nexit\n"          "does not exist"
check "open shows line numbers"         "open a.c\nexit\n"             "#include <stdio.h>"
check "open sets current file"          "open a.c\nexit\n"             "[a.c]"
check "unclosed quote is reported"      "create \"abc\nexit\n"         "Missing closing quote"

echo "== edit / save =="
check "built-in editor saves text"      "edit n.txt\nhello edit\n:wq\nshow n.txt\nexit\n" "hello edit"
check "built-in editor :q cancels"      "edit n.txt\nzzz\n:q\nexit\n"  "Nothing saved"
check "edit missing file"               "edit ghost.c\nexit\n"         "does not exist"
check "edit without file"               "edit\nexit\n"                 "No file selected"
check "save makes backup"               "open a.c\nsave\nexit\n"       "Backup kept"
check "save as copies file"             "open a.c\nsave a_copy.c\nls\nexit\n" "a_copy.c"
check "save as refuses overwrite"       "open a.c\nsave b.c\nexit\n"   "already exists"
check "save without a file"             "save\nexit\n"                 "No file selected"

echo "== delete =="
check "delete asks and removes (y)"     "create d.c\ndelete d.c\ny\nexit\n" "Deleted 'd.c'"
check "delete cancelled (n)"            "create e.c\ndelete e.c\nn\nexit\n" "Nothing was deleted"
check "delete missing file"             "delete ghost.c\nexit\n"       "does not exist"
check "delete clears current file"      "create f.c\ndelete f.c\ny\nstatus\nexit\n" "Current file : (none)"

echo "== Unix commands (teammate module) =="
check "search finds text"               "open a.c\nsearch Hello\nexit\n"        "Total matching lines: 1"
check "search -i ignores case"          "open a.c\nsearch hello a.c -i\nexit\n" "Total matching lines: 1"
check "search no match"                 "open a.c\nsearch zzzz\nexit\n"         "No matches found"
check "search without word"             "search\nexit\n"                        "Usage: search"
check "find by pattern"                 "find \"*.c\"\nexit\n"                  "Total files found"
check "count current file"              "open a.c\ncount\nexit\n"               "Lines"
check "sort current file"               "open a.c\nsort\nexit\n"                "include"
check "sort reverse"                    "open a.c\nsort -r\nexit\n"             "include"
check "head with number only"           "open a.c\nhead 2\nexit\n"              "First 2 line(s)"
check "tail with file and number"       "tail a.c 1\nexit\n"                    "Last 1 line(s)"
check "show prints whole file"          "show a.c\nexit\n"                      "return 0;"
check "no file selected is explained"   "count\nexit\n"                         "No file selected"
check "!command runs Unix command"      "!echo unix_works\nexit\n"              "unix_works"
check "unix keyword runs command"       "unix echo second_way\nexit\n"          "second_way"
check "failing unix command reported"   "!false\nexit\n"                        "exit code 1"

echo "== Hooks for other members' modules =="
check "compile module is loaded"         "status\nexit\n"                         "✔ Compile ready"
check "process module is loaded"         "status\nexit\n"                         "✔ Process ready"
check "report module is loaded"         "status\nexit\n"                         "✔ Report ready"
check "compile needs a file"            "compile\nexit\n"                       "No file selected"
check "commands are case-insensitive"   "HELP\nexit\n"                          "FILE COMMANDS"

# --- A fake module proves that new modules plug in automatically -------------
cat > "$HERE/modules/zz_fake_test.sh" <<'FAKE'
tark_compile() { echo "FAKE-COMPILE of $1"; }
tark_run()     { echo "FAKE-RUN of $1"; }
FAKE
echo "== Plug-in check (temporary fake module) =="
check "new module is detected"          "status\nexit\n"                        "Compile ready"
check "compile calls module function"   "open a.c\ncompile\nexit\n"             "FAKE-COMPILE of a.c"
check "menu 3 compiles then runs"       "open a.c\n3\nexit\n"                   "FAKE-RUN of a.c"
rm -f "$HERE/modules/zz_fake_test.sh"

echo "== Command-line options =="
out="$("$HERE/tark.sh" --version 2>&1)"
if [[ "$out" == TARK* ]]; then echo "  [PASS] --version"; pass=$((pass+1)); else echo "  [FAIL] --version"; fail=$((fail+1)); fi
out="$("$HERE/tark.sh" -c "help" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
if grep -q "FILE COMMANDS" <<< "$out"; then echo "  [PASS] -c runs one command"; pass=$((pass+1)); else echo "  [FAIL] -c runs one command"; fail=$((fail+1)); fi

echo
echo "------------------------------------------"
echo " RESULT: $pass passed, $fail failed"
echo "------------------------------------------"
[[ $fail -eq 0 ]]
