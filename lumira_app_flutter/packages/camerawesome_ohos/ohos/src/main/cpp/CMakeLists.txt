cmake_minimum_required(VERSION 3.5.0)
project(preview_fx)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 生成 libpreview_fx.so，供 CameraState.ets 以 `import previewFx from 'libpreview_fx.so'` 加载。
# 取景器实时特效 GPU 管线：相机预览流(NativeImage/OES) → OpenGL ES 着色器 → Flutter Texture(EGL 窗口)。
add_library(preview_fx SHARED preview_fx.cpp)
target_link_libraries(preview_fx PUBLIC
    libace_napi.z.so
    libEGL.so
    libGLESv3.so
    libnative_window.so
    libnative_image.so
    libhilog_ndk.z.so)
