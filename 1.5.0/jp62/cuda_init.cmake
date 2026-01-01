# cuda_init.cmake - Ensures CUDA is found before other packages
#
# This file is included via CMAKE_PROJECT_INCLUDE to ensure find_package(CUDA)
# is called early, which defines CUDA_FOUND and find_cuda_helper_libs macro.
# This is needed because some packages (via cudnn_cmake_module) call
# find_package(CUDNN) which requires CUDA to be found first.

if(NOT CUDA_FOUND)
  find_package(CUDA QUIET)
endif()
