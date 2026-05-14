#include <unistd.h>
#include <sys/wait.h>
#include <stdio.h>
#include <stdlib.h>

// Fork execution implementation
int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("[FORK] No commands provided.\n");
        return 0;
    }

    int num_cmds = argc - 1;
    pid_t *pids = malloc(num_cmds * sizeof(pid_t));
    
    // Fork a process for each command
    for (int i = 0; i < num_cmds; i++) {
        pids[i] = fork();
        if (pids[i] < 0) {
            perror("fork failed");
            exit(1);
        } else if (pids[i] == 0) {
            // Child process executes the command
            execl("/bin/bash", "bash", "-c", argv[i + 1], NULL);
            // If execl returns, it failed
            perror("execl failed");
            exit(1);
        } else {
            printf("[FORK] PID %d started : %s\n", pids[i], argv[i + 1]);
        }
    }

    int success_count = 0;
    int fail_count = 0;

    // Parent waits for all children
    for (int i = 0; i < num_cmds; i++) {
        int status;
        waitpid(pids[i], &status, 0);
        
        if (WIFEXITED(status)) {
            int exit_status = WEXITSTATUS(status);
            printf("[FORK] PID %d exited with status %d\n", pids[i], exit_status);
            if (exit_status == 0) {
                success_count++;
            } else {
                fail_count++;
            }
        } else {
            printf("[FORK] PID %d exited abnormally\n", pids[i]);
            fail_count++;
        }
    }

    printf("[FORK] Summary: %d succeeded, %d failed\n", success_count, fail_count);
    free(pids);
    
    return (fail_count > 0) ? 1 : 0;
}
