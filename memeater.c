#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/mman.h>
#include <assert.h>
#include <unistd.h>

#define NODE_MEM_SYS_RSV_SZMB (0)

int main(int argc, char **argv)
{
    uint64_t szmb;

    if (argc != 2) {
        printf("\nUsage: %s <MB-to-hog>\n", argv[0]);
        exit(1);
    }

    szmb = atoll(argv[1]) - NODE_MEM_SYS_RSV_SZMB;

    char *buf = calloc(1, szmb*1024*1024ULL);
    assert(buf);
    mlock((void *)szmb, szmb*1024*1024ULL);
    printf("Coperd, I have successfully hogged [%ld]MB memory\n", szmb);
    exit(1);

    sleep(10000);

    return 0;
}
