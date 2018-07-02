cmake_minimum_required(VERSION 3.10)
project(test2 C)

set(CMAKE_C_STANDARD 99)

add_executable(test2 main.c)
add_executable(test2-asan main.c)

set_target_properties(test2-asan PROPERTIES COMPILE_FLAGS "-fsanitize=address")

target_link_libraries(test2-asan -lasan)