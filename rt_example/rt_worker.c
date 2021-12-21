/*
 * Simple Example RT Kernel and worker code.
 * Mustafa Bayramov

 By default launch 10 thead, perform computation sample 1024 time
 and output time taken.

 Resolution.
clocks.c
                    clock	       res (ns)	           secs	          nsecs
             gettimeofday	          1,000	  1,391,886,268	    904,379,000
           CLOCK_REALTIME	              1	  1,391,886,268	    904,393,224
    CLOCK_REALTIME_COARSE	        999,848	  1,391,886,268	    903,142,905
          CLOCK_MONOTONIC	              1	        136,612	    254,536,227
      CLOCK_MONOTONIC_RAW	    870,001,632	        136,612	    381,306,122
   CLOCK_MONOTONIC_COARSE	        999,848	        136,612	    253,271,977
 */
#define _GNU_SOURCE

#include <limits.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <sched.h>
#include <math.h>
#include <memory.h>

#define DEFAULT_PRIORITY 99
#define DEFAULT_MAX_RUN 10
#define NUM_ITERATION_FACTOR 500
#define BINS 1024
#define MAX_THREADS 10

const int MAX_ITERATION = (NUM_ITERATION_FACTOR * NUM_ITERATION_FACTOR * NUM_ITERATION_FACTOR);

#define ONE_BILLION  1000000000L

struct deltas {
    double sum;
    double sum2;
    double min;
    double max;
    double avg;
    double median;
    double stdev;
};

void compute_deltas(struct deltas *delta_stats, long v[], int bin_size) {

    long x[bin_size];
    memcpy(x, v, bin_size * sizeof(long));

    int count = bin_size - 1;
    for (int i = 0; i < count; ++i) {
        x[i] = x[i + 1] - x[i];
    }

    for (int i = 0; i < count; ++i) {
        delta_stats->sum = delta_stats->sum + x[i];
        delta_stats->sum2 = delta_stats->sum2 + (x[i] * x[i]);
        if (x[i] > delta_stats->max)
            delta_stats->max = x[i];
        if ((delta_stats->min == -1) || (x[i] < delta_stats->min))
            delta_stats->min = x[i];
    }

    delta_stats->avg = delta_stats->sum / count;
    delta_stats->median = delta_stats->min + ((delta_stats->max - delta_stats->min) / 2);
    delta_stats->stdev = sqrt((count * delta_stats->sum2 - (delta_stats->sum * delta_stats->sum)) / (count * count));

}

void print_stats(int run, struct deltas *delta) {
    printf("%d\t%7.2f\t%7.2f\t%7.2f\t%7.2f\t%7.2f\n",
           run, delta->min, delta->max, delta->avg, delta->median, delta->stdev);
}

double worker(int clock_type, long *timestamp) {
    struct timespec start, end;
    clock_gettime(clock_type, &start);

    double sum = 0;
    double add = 1;

    for (int i = 0; i < MAX_ITERATION; i++) {
        struct timespec x;
        clock_gettime(clock_type, &x);
        // store trace
        timestamp[(i & (BINS - 1))] = (x.tv_sec * ONE_BILLION) + x.tv_nsec;
        sum += add;
        add /= 2.0;
    }

    clock_gettime(clock_type, &end);
    long seconds = end.tv_sec - start.tv_sec;
    long nanoseconds = end.tv_nsec - start.tv_nsec;
    double elapsed = seconds + nanoseconds * 1e-9;
    return elapsed;
}

void *thread_worker(void *data) {

    struct deltas stats[DEFAULT_MAX_RUN];
    double execution[DEFAULT_MAX_RUN];

    printf("%s\t%7s\t%7s\t%7s\t%7s\t%7s\n", "run", "min", "max", "avg", "median", "stdev");

    long timestamp[BINS] = {};
    for (int runs = 0; runs < DEFAULT_MAX_RUN; runs++) {
        memset(timestamp, 0, sizeof(timestamp));
        stats[runs].sum = 0;
        stats[runs].sum2 = 0;
        stats[runs].min = -1;
        stats[runs].max = 0;
        stats[runs].avg = 0;
        stats[runs].median = 0;
        stats[runs].stdev = 0;

        execution[runs] = worker(CLOCK_REALTIME, timestamp);
        compute_deltas(&stats[runs], timestamp, BINS);
    }

    for (int runs = 0; runs < DEFAULT_MAX_RUN; runs++) {
        print_stats(runs, &stats[runs]);
    }

//    for (int runs = 0; runs < DEFAULT_MAX_RUN; runs++) {
//        printf("Time measured: cpu %d %.3f seconds.\n", sched_getcpu(), execution[runs]);
//    }

    double mean = 0, sum = 0;
    for (int i = 1; i < DEFAULT_MAX_RUN; i++) {
        sum = sum + execution[i];
    }

    mean = sum / 10;
    printf("Mean execution time measured: cpu %d, mean %.3f seconds.\n", sched_getcpu(), mean);
    return NULL;
}

void error_exit(const char *msg) {
    printf("%s\n", msg);
    exit(-2);
}

int main(int argc, char *argv[]) {
    struct sched_param param;
    pthread_attr_t attr;
    pthread_t threads[MAX_THREADS];
    int ret;

    if (mlockall(MCL_CURRENT | MCL_FUTURE) == -1)
        error_exit("failed mlockall");

    /*
     * -Initialize pthread attributes
     * -Set stack size */
    ret = pthread_attr_init(&attr);
    if (ret)
        error_exit("init pthread attributes failed");

    ret = pthread_attr_setstacksize(&attr, PTHREAD_STACK_MIN * 100);
    if (ret)
        error_exit("pthread set stack size failed");

    ret = pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
    if (ret)
        error_exit("pthread set sched policy failed");

    param.sched_priority = DEFAULT_PRIORITY;
    ret = pthread_attr_setschedparam(&attr, &param);
    if (ret)
        error_exit("pthread set sched param failed.");

    ret = pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
    if (ret)
        error_exit("pthread set inherit sched failed.");

    for (int i = 0; i < MAX_THREADS; i++) {
        ret = pthread_create(&threads[i], &attr, thread_worker, NULL);
        if (ret)
            error_exit("create pthread failed\n");
    }
    for (int i = 0; i < MAX_THREADS; i++) {
        /* Join the thread and wait until it is done */
        ret = pthread_join(threads[i], NULL);
        if (ret)
            error_exit("join pthread failed: %m\n");
    }
    return ret;
}