# FindCUDA.cmake - Wrapper that provides both legacy and modern CUDA CMake APIs
#
# Some packages use find_package(CUDA) but link to CUDA::cudart (modern target).
# This wrapper calls find_package(CUDAToolkit) to create CUDA::* targets,
# then sets legacy CUDA_* variables for backward compatibility.

# First, find CUDAToolkit which creates modern CUDA::* targets
if(NOT CUDAToolkit_FOUND)
  find_package(CUDAToolkit QUIET)
endif()

if(CUDAToolkit_FOUND)
  # Set default CUDA standard to C++17 for packages using native CMake CUDA support
  # This is needed because Autoware uses C++17 features like std::optional, if constexpr
  set(CMAKE_CUDA_STANDARD 17 CACHE STRING "CUDA C++ standard")
  set(CMAKE_CUDA_STANDARD_REQUIRED ON CACHE BOOL "Require CUDA C++ standard")

  # Set legacy variables for packages using old FindCUDA API
  set(CUDA_FOUND TRUE)
  set(CUDA_VERSION "${CUDAToolkit_VERSION}")
  set(CUDA_VERSION_STRING "${CUDAToolkit_VERSION}")
  set(CUDA_VERSION_MAJOR "${CUDAToolkit_VERSION_MAJOR}")
  set(CUDA_VERSION_MINOR "${CUDAToolkit_VERSION_MINOR}")
  set(CUDA_INCLUDE_DIRS "${CUDAToolkit_INCLUDE_DIRS}")
  set(CUDA_TOOLKIT_ROOT_DIR "${CUDAToolkit_LIBRARY_ROOT}")

  # Get the actual library path for legacy variable
  if(TARGET CUDA::cudart)
    get_target_property(_cudart_location CUDA::cudart IMPORTED_LOCATION)
    if(NOT _cudart_location)
      get_target_property(_cudart_location CUDA::cudart IMPORTED_LOCATION_RELEASE)
    endif()
    set(CUDA_CUDART_LIBRARY "${_cudart_location}")
    set(CUDA_LIBRARIES "${_cudart_location}")
  endif()

  # Find nvcc for cuda_add_library compatibility
  find_program(CUDA_NVCC_EXECUTABLE nvcc
    HINTS ${CUDAToolkit_BIN_DIR} ${CUDA_TOOLKIT_ROOT_DIR}/bin
    PATH_SUFFIXES bin
  )

  # Set CUDA_TOOLKIT_TARGET_DIR for library searches
  set(CUDA_TOOLKIT_TARGET_DIR "${CUDAToolkit_LIBRARY_ROOT}")

  message(STATUS "FindCUDA wrapper: Using CUDAToolkit ${CUDAToolkit_VERSION}")
  message(STATUS "  CUDA_INCLUDE_DIRS: ${CUDA_INCLUDE_DIRS}")
  message(STATUS "  CUDA::cudart target: available")
else()
  set(CUDA_FOUND FALSE)
  message(WARNING "FindCUDA wrapper: CUDAToolkit not found")
endif()

# Legacy macro: cuda_find_library_local_first_with_path_ext
# Used by find_cuda_helper_libs to locate CUDA libraries
macro(cuda_find_library_local_first_with_path_ext _var _names _doc _path_ext)
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(_cuda_64bit_lib_dir "${_path_ext}lib/x64" "${_path_ext}lib64" "${_path_ext}libx64")
  endif()
  find_library(${_var}
    NAMES ${_names}
    PATHS "${CUDA_TOOLKIT_TARGET_DIR}"
    ENV CUDA_PATH
    ENV CUDA_LIB_PATH
    PATH_SUFFIXES ${_cuda_64bit_lib_dir} "${_path_ext}lib/Win32" "${_path_ext}lib" "${_path_ext}libWin32"
    DOC ${_doc}
    NO_DEFAULT_PATH
  )
  # Search in additional system paths (needed for cuDNN on aarch64)
  if(NOT ${_var})
    find_library(${_var}
      NAMES ${_names}
      PATHS
        "/usr/lib/aarch64-linux-gnu"
        "/usr/lib/x86_64-linux-gnu"
        "/usr/lib"
        "/usr/local/lib"
        "/usr/lib/nvidia-current"
      DOC ${_doc}
    )
  endif()
endmacro()

# Legacy macro: cuda_find_library_local_first
macro(cuda_find_library_local_first _var _names _doc)
  cuda_find_library_local_first_with_path_ext("${_var}" "${_names}" "${_doc}" "")
endmacro()

# Legacy macro: find_cuda_helper_libs
# Used by ROS cudnn_cmake_module to find cudnn library
macro(find_cuda_helper_libs _name)
  cuda_find_library_local_first(CUDA_${_name}_LIBRARY ${_name} "\"${_name}\" library")
  mark_as_advanced(CUDA_${_name}_LIBRARY)
endmacro()

# Compatibility macro for cuda_add_library
# Creates a library with CUDA language support for .cu files
macro(cuda_add_library target_name)
  # Enable CUDA language if not already enabled
  get_property(_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
  if(NOT "CUDA" IN_LIST _languages)
    enable_language(CUDA)
  endif()

  # Parse arguments to separate source files from keywords
  set(_cuda_sources)
  set(_type SHARED)  # default

  foreach(_arg ${ARGN})
    if(_arg STREQUAL "STATIC")
      set(_type STATIC)
    elseif(_arg STREQUAL "SHARED")
      set(_type SHARED)
    elseif(_arg STREQUAL "MODULE")
      set(_type MODULE)
    elseif(_arg STREQUAL "EXCLUDE_FROM_ALL")
      # ignore
    else()
      list(APPEND _cuda_sources ${_arg})
    endif()
  endforeach()

  add_library(${target_name} ${_type} ${_cuda_sources})
  target_include_directories(${target_name} PUBLIC ${CUDA_INCLUDE_DIRS})
  # Note: Don't link here - let packages handle their own linking to avoid
  # keyword/plain signature conflicts with target_link_libraries

  # Set CUDA properties - use explicit architectures for cross-compilation
  # (native detection fails in QEMU without GPU)
  # 75=Turing, 86=Ampere, 87=Orin, 89=Ada Lovelace
  set_target_properties(${target_name} PROPERTIES
    CUDA_STANDARD 17
    CUDA_STANDARD_REQUIRED ON
    CUDA_ARCHITECTURES "75;86;87;89"
  )

  # Enable separable compilation if CUDA_SEPARABLE_COMPILATION is set
  # This is needed when __device__ functions are defined in one .cu file
  # and called from another .cu file
  if(CUDA_SEPARABLE_COMPILATION)
    set_target_properties(${target_name} PROPERTIES
      CUDA_SEPARABLE_COMPILATION ON
    )
  endif()

  # Apply CUDA_NVCC_FLAGS if set (for compatibility with old FindCUDA usage)
  if(CUDA_NVCC_FLAGS)
    # Convert list to space-separated string for CMAKE_CUDA_FLAGS
    string(REPLACE ";" " " _nvcc_flags_str "${CUDA_NVCC_FLAGS}")
    set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} ${_nvcc_flags_str}")
  endif()

  # Clear directory-level compile options and re-add only for C++
  # This prevents C++ flags like -Werror from being passed to nvcc
  get_directory_property(_dir_compile_opts COMPILE_OPTIONS)
  set_property(TARGET ${target_name} PROPERTY COMPILE_OPTIONS "")
  foreach(_opt ${_dir_compile_opts})
    target_compile_options(${target_name} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${_opt}>)
  endforeach()
endmacro()

# Compatibility macro for cuda_add_executable
macro(cuda_add_executable target_name)
  # Enable CUDA language if not already enabled
  get_property(_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
  if(NOT "CUDA" IN_LIST _languages)
    enable_language(CUDA)
  endif()

  add_executable(${target_name} ${ARGN})
  target_include_directories(${target_name} PUBLIC ${CUDA_INCLUDE_DIRS})
  # Note: Don't link here - let packages handle their own linking to avoid
  # keyword/plain signature conflicts with target_link_libraries

  # Set CUDA properties - use explicit architectures for cross-compilation
  set_target_properties(${target_name} PROPERTIES
    CUDA_STANDARD 17
    CUDA_STANDARD_REQUIRED ON
    CUDA_ARCHITECTURES "75;86;87;89"
    CUDA_SEPARABLE_COMPILATION ON
  )

  # Clear directory-level compile options and re-add only for C++
  # This prevents C++ flags like -Werror from being passed to nvcc
  get_directory_property(_dir_compile_opts COMPILE_OPTIONS)
  set_property(TARGET ${target_name} PROPERTY COMPILE_OPTIONS "")
  foreach(_opt ${_dir_compile_opts})
    target_compile_options(${target_name} PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${_opt}>)
  endforeach()
endmacro()
