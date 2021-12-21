## Example real time app for RT kernel.


By default, it starts ten threads. Each thread does some work,  each iteration. It computation time that took computation, at the end of iteration compute stats stdev, mean etc.

It can be easily seen if the system is not optimized correctly, properly configured, and delta time between threads falls apart.

Note if you are going to increase the sample size, make sure to adjust the default thread stack size. 

```bash
gcc -g -o rt_wroker rt_wroker.c  -lpthread -lm; rt_test
```