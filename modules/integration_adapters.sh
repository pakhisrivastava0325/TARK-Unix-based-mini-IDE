#!/usr/bin/env bash
# Adapters between the main CLI API and Nysa's execution module.
tark_compile() { compile_c "$@"; }
tark_run() { execute_program "$@"; }
# tark_process is implemented by project_tools.sh so it can demonstrate fork/exec/wait.
