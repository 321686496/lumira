cmake_minimum_required(VERSION 3.5.0)
project(lumira_photo_processor)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 生成 libphoto_processor.so，供 ArkTS 以 `import x from 'libphoto_processor.so'` 加载
add_library(photo_processor SHARED photo_processor.cpp)
target_link_libraries(photo_processor PUBLIC libace_napi.z.so)