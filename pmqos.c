/*
 * Disable power management: similar to ``processor.max_cstate=1 idle=poll``
 * in kernel arguments, check https://access.redhat.com/articles/65410
 */

#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static int pm_qos_fd = -1;

void start_low_latency(void)
{
    int target = 0;

    if (pm_qos_fd >= 0)
        return;

    pm_qos_fd = open("/dev/cpu_dma_latency", O_RDWR);
    if (pm_qos_fd < 0) {
        fprintf(stderr, "Failed to open PM QOS file: %s\n", strerror(errno));
        exit(errno);
    }
    write(pm_qos_fd, &target, sizeof(target));
}

void stop_low_latency(void)
{
    if (pm_qos_fd >= 0) {
        close(pm_qos_fd);
    }
}

int main(int argc, char **argv)
{
    start_low_latency();
    pause();
    stop_low_latency();

    return 0;
}
