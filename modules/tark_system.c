/* TARK Unix system-call helper: fork, exec, wait, pipe and dup2. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int wait_child(pid_t pid, const char *label) {
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno == EINTR) continue;
        perror("waitpid"); return 1;
    }
    if (WIFEXITED(status)) {
        int code = WEXITSTATUS(status);
        fprintf(stderr, "[TARK] %s exited with status %d\n", label, code);
        return code;
    }
    if (WIFSIGNALED(status)) {
        fprintf(stderr, "[TARK] %s terminated by signal %d\n", label, WTERMSIG(status));
        return 128 + WTERMSIG(status);
    }
    return 1;
}
static void run_shell(const char *command) {
    execl("/bin/bash", "bash", "-c", command, (char *)NULL);
    perror("exec (/bin/bash)"); _exit(127);
}
int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: tark_sys proc COMMAND | pipe COMMAND1 COMMAND2 | input FILE COMMAND | output FILE COMMAND | append FILE COMMAND\n");
        return 2;
    }
    if (!strcmp(argv[1], "proc")) {
        fflush(stdout);
        pid_t pid = fork();
        if (pid < 0) { perror("fork"); return 1; }
        if (pid == 0) run_shell(argv[2]);
        printf("[TARK] Parent created child process PID %ld using fork().\n", (long)pid);
        int rc = wait_child(pid, "Child process");
        printf("[TARK] Parent resumed after wait().\n");
        return rc;
    }
    if (!strcmp(argv[1], "pipe")) {
        if (argc < 4) { fprintf(stderr, "pipe requires two commands\n"); return 2; }
        int fd[2];
        fflush(stdout);
        if (pipe(fd) < 0) { perror("pipe"); return 1; }
        pid_t left = fork();
        if (left < 0) { perror("fork left"); return 1; }
        if (left == 0) {
            close(fd[0]);
            if (dup2(fd[1], STDOUT_FILENO) < 0) { perror("dup2 stdout"); _exit(1); }
            close(fd[1]); run_shell(argv[2]);
        }
        pid_t right = fork();
        if (right < 0) { perror("fork right"); close(fd[0]); close(fd[1]); (void)wait_child(left,"left command"); return 1; }
        if (right == 0) {
            close(fd[1]);
            if (dup2(fd[0], STDIN_FILENO) < 0) { perror("dup2 stdin"); _exit(1); }
            close(fd[0]); run_shell(argv[3]);
        }
        close(fd[0]); close(fd[1]);
        fprintf(stderr, "[TARK] pipe() connected two child processes; parent waits for both.\n");
        int a = wait_child(left, "Left command");
        int b = wait_child(right, "Right command");
        return b ? b : a;
    }
    if (!strcmp(argv[1], "input") || !strcmp(argv[1], "output") || !strcmp(argv[1], "append")) {
        if (argc < 4) { fprintf(stderr, "redirection requires FILE and COMMAND\n"); return 2; }
        int flags = O_RDONLY;
        int target = STDIN_FILENO;
        if (!strcmp(argv[1], "output")) { flags = O_WRONLY | O_CREAT | O_TRUNC; target = STDOUT_FILENO; }
        if (!strcmp(argv[1], "append")) { flags = O_WRONLY | O_CREAT | O_APPEND; target = STDOUT_FILENO; }
        int fd = open(argv[2], flags, 0644);
        if (fd < 0) { perror("open redirection file"); return 1; }
        pid_t pid = fork();
        if (pid < 0) { perror("fork"); close(fd); return 1; }
        if (pid == 0) {
            if (dup2(fd, target) < 0) { perror("dup2"); _exit(1); }
            close(fd); run_shell(argv[3]);
        }
        close(fd);
        fprintf(stderr, "[TARK] fork() created redirection child; dup2() connected file descriptor.\n");
        return wait_child(pid, "Redirection command");
    }
    fprintf(stderr, "Unknown helper operation: %s\n", argv[1]);
    return 2;
}
