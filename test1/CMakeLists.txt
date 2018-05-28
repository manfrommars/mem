cmake_minimum_required(VERSION 3.10)
project(test1 C)

set(CMAKE_C_STANDARD 99)

add_executable(test1 main.c)
add_executable(test1-asan main.c)

set_target_properties(test1-asan PROPERTIES COMPILE_FLAGS "-fsanitize=address")

target_link_libraries(test1-asan -lasan)
