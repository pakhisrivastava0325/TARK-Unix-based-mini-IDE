# TARK – Unix-Based Mini IDE
## Module: Search and Unix Utilities

A self-contained Bash module that provides **7 functions** for searching and
inspecting text files. It uses only standard Unix commands:
`grep`, `find`, `wc`, `sort`, `head`, `tail`, `cat`.

---

## 1. Folder Structure

```
TARK_Search_Utilities/
├── search.sh        # search_text(), find_files()
├── utilities.sh     # count_content(), sort_content(), show_head(), show_tail(), display_file()
├── test_module.sh   # interactive menu  +  automated self-test (--auto)
├── README.md        # this documentation
└── sample_data/     # ready-made files used by the test cases below
    ├── sample.txt   fruits.txt   numbers.txt   empty.txt   "my notes.txt"
    ├── "empty dir"/
    └── project/
        ├── src/main.sh
        └── docs/notes.txt   "my report.txt"
```

| Function | File | Unix command used |
|---|---|---|
| `search_text()`   | search.sh    | `grep -n` (`-F`, `-i`) |
| `find_files()`    | search.sh    | `find -type f -name` |
| `count_content()` | utilities.sh | `wc -l`, `wc -w`, `wc -m` |
| `sort_content()`  | utilities.sh | `sort` (`-r`) |
| `show_head()`     | utilities.sh | `head -n` |
| `show_tail()`     | utilities.sh | `tail -n` |
| `display_file()`  | utilities.sh | `cat` |

---

## 2. Requirements

* Linux (or any system with **Bash 4.3+** (any modern Linux; the macOS default Bash 3.2 is too old) and GNU coreutils/grep/findutils)
* Check your Bash version: `bash --version`

---

## 3. How to Run

```bash
cd TARK_Search_Utilities
chmod +x *.sh                 # one-time: make scripts executable
```

**A. Interactive menu**
```bash
./test_module.sh
```

**B. Automated self-test (58 checks, creates and deletes its own temp files)**
```bash
./test_module.sh --auto
```
Expected last lines:
```
 RESULT: 58 passed, 0 failed
```

**C. Call a single function from the terminal**
```bash
./search.sh    search_text "hello" "sample_data/sample.txt" -i
./search.sh    find_files  "*.txt" "sample_data/project"
./utilities.sh show_head   "sample_data/numbers.txt" 3
```

**D. Use the functions inside your own shell/script**
```bash
source ./search.sh
source ./utilities.sh
search_text "main" "app.c"
count_content "my file.txt"
```

> Always run with **Bash** (`./script.sh` or `bash script.sh`), not `sh script.sh`.
> The scripts detect this and print a clear message if you forget.

---

## 4. Function Reference

All functions print results to the screen, errors to *stderr*, and return an exit code.

**Return codes:** `0` = success, `1` = bad input / error, `2` = valid request but nothing found
(`search_text` and `find_files` only).

| Function | Arguments | Description |
|---|---|---|
| `search_text` | `word file [-i]` | Prints matching lines as `LINE:TEXT`, then a total. `-i` ignores case. The word is searched literally. |
| `find_files` | `pattern [dir]` | Lists files by name under `dir` (default `.`), recursively. A word with no wildcard (`report`) matches as `*report*`. |
| `count_content` | `file` | Shows lines, words, characters. |
| `sort_content` | `file [-r]` | Prints sorted lines. `-r` reverses. **Never modifies the file.** |
| `show_head` | `file [n]` | First `n` lines (default 10). |
| `show_tail` | `file [n]` | Last `n` lines (default 10). |
| `display_file` | `file` | Prints the whole file. |

### Input handling built into every function
| Situation | Behaviour |
|---|---|
| Empty input (word, file, pattern) | Error message, return 1 |
| File does not exist / is a directory / unreadable | Error message, return 1 |
| Directory missing / not a directory / no permission | Error message, return 1 |
| Line count not a positive whole number (`abc`, `0`, `-5`) | Error message, return 1 |
| Empty file | Friendly note `(file '...' is empty)`; counts show 0 |
| File names with spaces | Work (every variable is double-quoted) |
| Sorting | Output goes to screen only – original file untouched |

---

## 5. Test Cases with Expected Output

Run these from the `TARK_Search_Utilities` folder after `source ./search.sh; source ./utilities.sh`.
(Outputs below were produced by actually running the commands.)

Contents of `sample_data/sample.txt`:
```
Hello World
unix is powerful
HELLO again
banana
apple
cherry
```

### search_text
| # | Command | Expected output | Exit |
|---|---|---|---|
| 1 | `search_text "Hello" sample_data/sample.txt` | `Matches for 'Hello' in 'sample_data/sample.txt':`<br>`1:Hello World`<br>`Total matching lines: 1` | 0 |
| 2 | `search_text "hello" sample_data/sample.txt` | `No matches found for 'hello' in 'sample_data/sample.txt'.` | 2 |
| 3 | `search_text "hello" sample_data/sample.txt -i` | `1:Hello World`<br>`3:HELLO again`<br>`Total matching lines: 2` | 0 |
| 4 | `search_text "linux" "sample_data/my notes.txt"` | `1:linux rocks` (file with a space works) | 0 |
| 5 | `search_text "hello" nofile.txt` | `Error: file 'nofile.txt' does not exist.` | 1 |
| 6 | `search_text "" sample_data/sample.txt` | `Error: search word is empty.` | 1 |
| 7 | `search_text "x" sample_data/project` | `Error: 'sample_data/project' is a directory, not a file.` | 1 |

### find_files
| # | Command | Expected output | Exit |
|---|---|---|---|
| 8 | `find_files "*.txt" sample_data/project` | `sample_data/project/docs/my report.txt`<br>`sample_data/project/docs/notes.txt`<br>`Total files found: 2` | 0 |
| 9 | `find_files report sample_data/project` | `Files matching '*report*' ...`<br>`sample_data/project/docs/my report.txt` | 0 |
| 10 | `find_files "*.xyz" sample_data/project` | `No files matching '*.xyz' found in 'sample_data/project'.` | 2 |
| 11 | `find_files "*.txt" /no/such/dir` | `Error: directory '/no/such/dir' does not exist.` | 1 |
| 12 | `find_files "" .` | `Error: file name pattern is empty.` | 1 |

### count_content
| # | Command | Expected output | Exit |
|---|---|---|---|
| 13 | `count_content sample_data/sample.txt` | `Lines      : 6`<br>`Words      : 10`<br>`Characters : 61` | 0 |
| 14 | `count_content "sample_data/my notes.txt"` | `Lines : 2`, `Words : 4`, `Characters : 24` | 0 |
| 15 | `count_content sample_data/empty.txt` | `Lines : 0`, `Words : 0`, `Characters : 0` | 0 |
| 16 | `count_content nofile.txt` | `Error: file 'nofile.txt' does not exist.` | 1 |

### sort_content  (`fruits.txt` = banana, apple, cherry)
| # | Command | Expected output | Exit |
|---|---|---|---|
| 17 | `sort_content sample_data/fruits.txt` | `apple`, `banana`, `cherry` | 0 |
| 18 | `sort_content sample_data/fruits.txt -r` | `cherry`, `banana`, `apple` | 0 |
| 19 | `sort_content sample_data/fruits.txt; cat sample_data/fruits.txt` | `cat` still shows `banana, apple, cherry` → **original not changed** | 0 |
| 20 | `sort_content sample_data/fruits.txt -z` | `Error: unknown option '-z' (only -r is allowed).` | 1 |

### show_head / show_tail  (`numbers.txt` = 1 to 15)
| # | Command | Expected output | Exit |
|---|---|---|---|
| 21 | `show_head sample_data/numbers.txt` | `First 10 line(s)...` then `1` to `10` | 0 |
| 22 | `show_head sample_data/numbers.txt 3` | `1`, `2`, `3` | 0 |
| 23 | `show_head sample_data/numbers.txt abc` | `Error: 'abc' is not a valid positive number.` | 1 |
| 24 | `show_tail sample_data/numbers.txt` | `Last 10 line(s)...` then `6` to `15` | 0 |
| 25 | `show_tail sample_data/numbers.txt 2` | `14`, `15` | 0 |
| 26 | `show_tail sample_data/empty.txt` | `(file 'sample_data/empty.txt' is empty)` | 0 |

### display_file
| # | Command | Expected output | Exit |
|---|---|---|---|
| 27 | `display_file "sample_data/my notes.txt"` | `linux rocks`<br>`second line` | 0 |
| 28 | `display_file sample_data/empty.txt` | `(file 'sample_data/empty.txt' is empty)` | 0 |
| 29 | `display_file sample_data/project` | `Error: 'sample_data/project' is a directory, not a file.` | 1 |
| 30 | `display_file` (no argument) | `Error: file name is empty.` | 1 |

### Menu tests (run `./test_module.sh`)
| # | You type | Expected |
|---|---|---|
| 31 | `9` | `Invalid choice '9'. Please type a number from 0 to 7.` – menu shows again |
| 32 | (just press Enter) | `No choice entered. Please type a number from 0 to 7.` |
| 33 | `abc` | `Invalid choice 'abc' ...` |
| 34 | `7`, then `sample_data/my notes.txt` (quotes optional) | file contents are shown |
| 35 | `1`, `hello`, `sample_data/sample.txt`, `y` | lines 1 and 3 are shown |
| 36 | `0` (or Ctrl+D) | `Goodbye! Exiting Search & Utilities module.` and the script ends |

All of the above are also checked automatically by `./test_module.sh --auto`.

---

## 6. Integrating This Module into the Main TARK Project

The module is independent: it uses no global variables, never calls `exit` or `set -e`
when sourced, and every helper starts with `_search_` or `_util_` to avoid name clashes.

```bash
# In the main TARK script:
TARK_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/TARK_Search_Utilities"
source "$TARK_MODULE_DIR/search.sh"
source "$TARK_MODULE_DIR/utilities.sh"

# then call any of the 7 functions, and check the exit code:
if search_text "TODO" "$current_file" -i; then
    echo "Found TODOs"
fi
```
Exit codes (`0` / `1` / `2`) let the main project react without parsing text.

---

## 7. Design Notes (good points to mention in your demo)

* **Quoting every variable** (`"$file"`) is what makes names with spaces work.
* **`--`** before the file/word tells commands "options end here", so a word like `-x` is not mistaken for an option.
* **`grep -F`** searches literal text, so `[`, `.` or `*` do not cause regex errors.
* **`wc < file`** (input redirection) prints only the number, with no file name.
* **`local`** keeps variables private to each function.
* **`${BASH_SOURCE[0]} == $0`** is true only when the file is *run*, not *sourced* – that is how the same file works both ways.
* Sorting writes to the **screen only** – no redirection onto the source file, so nothing is overwritten.
* Sorting order depends on your locale (`LANG`). For strict ASCII order use `LC_ALL=C sort_content file`.

**Known limitations:** `search_text` searches one file at a time (not recursive);
`find_files` matches by name only (not by size/date).

---

## 8. UNIX Viva Questions and Answers

### Shell scripting basics
**Q1. What is a shell? What is Bash?**
The shell is a program that reads your commands and asks the kernel to run them. Bash (Bourne Again SHell) is the most common Linux shell and also a scripting language.

**Q2. What does `#!/usr/bin/env bash` mean?**
It is the *shebang*. It tells the system which interpreter should run the script. `env bash` finds Bash wherever it is installed.

**Q3. Why `chmod +x script.sh`?**
It gives the file the *execute* permission so it can be run as `./script.sh`.

**Q4. Difference between `source file.sh` and `./file.sh`?**
`./file.sh` starts a **new** process; its functions and variables vanish when it ends. `source file.sh` (same as `. file.sh`) runs the file in the **current** shell, so its functions stay available. That is why test_module.sh uses `source`.

**Q5. What is `$0`, `$1`, `$@`, `$?`, `$#`?**
`$0` script name, `$1` first argument, `$@` all arguments (each kept separate when quoted), `$?` exit status of the last command, `$#` number of arguments.

**Q6. What is an exit status?**
A number returned by every command: `0` = success, non-zero = failure. This module uses 0 (ok), 1 (error), 2 (nothing found).

**Q7. Why do we quote variables like `"$file"`?**
Without quotes, Bash splits on spaces: `my notes.txt` becomes two arguments (`my` and `notes.txt`). Quotes keep it as one.

**Q8. Difference between `[ ]` and `[[ ]]`?**
`[ ]` is the older POSIX `test` command. `[[ ]]` is a Bash keyword: safer with spaces, and supports `&&`, `||`, pattern matching (`==` with `*`) and regex (`=~`).

**Q9. What does `local` do?**
Makes a variable visible only inside its function, so it cannot clash with the caller's variables.

**Q10. What does `read -r` do? Why `IFS=`?**
`read` takes a line of input. `-r` stops backslashes being treated as escapes. `IFS=` stops it trimming leading/trailing spaces.

**Q11. What does `${2:-10}` mean?**
"Use `$2`, but if it is unset or empty use `10`." It gives `show_head` its default of 10 lines.

### The seven commands
**Q12. What does `grep` do? Explain `-n`, `-i`, `-F`.**
`grep` prints lines that match a pattern. `-n` adds line numbers, `-i` ignores case, `-F` treats the pattern as plain text instead of a regular expression.

**Q13. What does `grep` return when nothing matches?**
Exit status `1` (and `2` for errors such as a missing file). `search_text` turns "no match" into return code 2.

**Q14. Difference between `grep` and `find`?**
`grep` searches **inside** files (contents). `find` searches the file system for files by **name, type, size, date, etc.**

**Q15. Explain `find . -type f -name "*.txt"`.**
Start in the current directory (`.`), look at regular files only (`-type f`), whose name matches `*.txt`. Search is recursive by default.

**Q16. Why quote `"*.txt"` in `find -name`?**
So the *shell* does not expand it first; `find` must receive the raw pattern.

**Q17. What do `wc -l`, `-w`, `-c`, `-m` count?**
Lines, words, bytes, characters. (They differ for non-English text: `é` is 1 character but 2 bytes in UTF-8.)

**Q18. Why `wc -l < file` instead of `wc -l file`?**
With `< file` wc reads from standard input, so it prints only the number, not the file name – easier to reuse in a script.

**Q19. How does `sort` work by default? Name some options.**
Sorts lines alphabetically by the locale rules. `-r` reverse, `-n` numeric, `-u` unique, `-k` sort by a column.

**Q20. How did you make sure sorting does not overwrite the original file?**
`sort` only writes to standard output (the screen). I never redirect back to the same file. (Note: `sort file > file` would actually **empty** the file, because the shell truncates it before sort reads it. `sort -o file file` is the safe in-place form.)

**Q21. What are the defaults of `head` and `tail`?**
Both show 10 lines. `head -n 3` first 3; `tail -n 3` last 3. `tail -f` follows a growing file (used for logs).

**Q22. What does `cat` stand for? Other uses?**
"concatenate". It displays files, and can join them: `cat a.txt b.txt > all.txt`. `cat -n` numbers lines.

### Concepts
**Q23. What are stdin, stdout and stderr?**
File descriptors 0, 1, 2: standard input (keyboard), standard output (screen), standard error (screen, for errors). My error messages use `>&2` so they go to stderr and do not mix with normal results.

**Q24. Explain `>`, `>>`, `<`, `|`, `2>/dev/null`.**
`>` write to file (overwrite), `>>` append, `<` read input from file, `|` pass one command's output to the next, `2>/dev/null` throw away error messages.

**Q25. What is a wildcard? Examples?**
Special characters the shell expands: `*` any characters, `?` exactly one character, `[abc]` one of a, b, c.

**Q26. What is the difference between a wildcard and a regular expression?**
Wildcards match **file names** and are expanded by the shell (`*.txt`). Regular expressions match **text patterns** and are used by tools like grep and sed (`.*` means "anything").

**Q27. What are Linux file permissions (rwx)?**
Read, write, execute for owner, group and others. Example `-rwxr-xr--` = owner rwx, group r-x, others r--. `chmod 755 file` sets them numerically.

**Q28. What is `$(command)`?**
Command substitution: runs the command and replaces itself with its output, e.g. `count=$(wc -l < file)`.

**Q29. What is an array and why did you use one for grep options?**
An array holds several values: `options=(-n -F)`. `"${options[@]}"` expands each as a separate, safely-quoted argument, and I can add `-i` only when needed.

**Q30. Why does the module not use `set -e` or `exit` inside functions?**
Because it is meant to be *sourced* into another project. `exit` or `set -e` would close or change the other team member's shell/script. Functions use `return` instead.

**Q31. What does `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` do?**
It checks whether the file is being executed directly (true) or sourced (false), so the "run from terminal" block is skipped when imported.

**Q32. What is a function's return value in Bash?**
Only an exit status number (0–255), set with `return`. Text results are *printed*, and the caller captures them with `$(...)`.

---

## 9. Quick Troubleshooting

| Problem | Fix |
|---|---|
| `Permission denied` when running `./test_module.sh` | `chmod +x *.sh` |
| `source: not found` / `[[: not found` | You used `sh`. Use `bash script.sh` |
| `bad interpreter: /usr/bin/env bash^M` | File has Windows line endings. Run `sed -i 's/\r$//' *.sh` (or `dos2unix *.sh`) |
| `find_files` shows nothing for `*.txt` | Quote the pattern: `"*.txt"` |
| File name not found in the menu | Type the path exactly; quotes around it are optional |
