cmake_minimum_required(VERSION 3.21)
project(rt_example C)

set(CMAKE_C_STANDARD 11)

add_executable(rt_example
        rt_example/rt_worker.c)
