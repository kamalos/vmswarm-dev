#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

// Thread execution implementation

pthread_mutex_t print_mutex = PTHREAD_MUTEX_INITIALIZER;

struct thread_arg {
    int id;
    char *cmd;
    int retcode;
};

void *run_cmd(void *arg) {
    struct thread_arg *a = (struct thread_arg *)arg;
    
    pthread_mutex_lock(&print_mutex);
    printf("[THREAD %d] starting: %s\n", a->id, a->cmd);
    pthread_mutex_unlock(&print_mutex);
    
    a->retcode = system(a->cmd);
    
    // Extract actual exit code if normal termination
    if (WIFEXITED(a->retcode)) {
        a->retcode = WEXITSTATUS(a->retcode);
    } else {
        a->retcode = 1; // Mark as generic failure
    }
    
    pthread_mutex_lock(&print_mutex);
    printf("[THREAD %d] finished: status %d\n", a->id, a->retcode);
    pthread_mutex_unlock(&print_mutex);
    
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("[THREAD] No commands provided.\n");
        return 0;
    }

    int num_cmds = argc - 1;
    pthread_t *threads = malloc(num_cmds * sizeof(pthread_t));
    struct thread_arg *args = malloc(num_cmds * sizeof(struct thread_arg));

    for (int i = 0; i < num_cmds; i++) {
        args[i].id = i + 1;
        args[i].cmd = argv[i + 1];
        args[i].retcode = -1;
        
        if (pthread_create(&threads[i], NULL, run_cmd, &args[i]) != 0) {
            perror("pthread_create failed");
            args[i].retcode = 1;
        }
    }

    int success_count = 0;
    int fail_count = 0;

    for (int i = 0; i < num_cmds; i++) {
        pthread_join(threads[i], NULL);
        if (args[i].retcode == 0) {
            success_count++;
        } else {
            fail_count++;
        }
    }

    printf("[THREAD] Summary: %d succeeded, %d failed\n", success_count, fail_count);

    free(threads);
    free(args);

    return (fail_count > 0) ? 1 : 0;
}
