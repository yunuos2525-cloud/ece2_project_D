cmake_minimum_required(VERSION 3.24)
project(ece2_project_d_stm32 LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_library(audio_core STATIC src/audio_dsp.c src/fpga_link.c src/audio_control.c)
target_include_directories(audio_core PUBLIC include)
if(NOT MSVC)
    target_link_libraries(audio_core PUBLIC m)
endif()

if(NOT CMAKE_CROSSCOMPILING)
    enable_testing()
    add_executable(audio_test tests/audio_test.c)
    target_link_libraries(audio_test PRIVATE audio_core)
    add_test(NAME audio_control COMMAND audio_test)
    return()
endif()

enable_language(ASM)
include(FetchContent)
if(STM32_BOARD STREQUAL "NUCLEO_G474RE")
    set(family g4)
    set(device STM32G474xx)
    set(board_suffix g474re)
    set(hal_commit a6001282dfacfff57e9710250f15e4333b578865)
    set(device_commit 626ee412334a5ed2e5b320af5a8d77d69f03a558)
elseif(STM32_BOARD STREQUAL "NUCLEO_H533RE")
    set(family h5)
    set(device STM32H533xx)
    set(board_suffix h533re)
    set(hal_commit deaf9d1da8a7b2958b5e0f0937bf6676ca0cd307)
    set(device_commit 884b8dc78e41cbfca008363342b17f4a9e8641f7)
else()
    message(FATAL_ERROR "Unsupported STM32_BOARD: ${STM32_BOARD}")
endif()

FetchContent_Declare(st_hal
    URL "https://codeload.github.com/STMicroelectronics/stm32${family}xx-hal-driver/tar.gz/${hal_commit}"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_Declare(st_device
    URL "https://codeload.github.com/STMicroelectronics/cmsis-device-${family}/tar.gz/${device_commit}"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_Declare(arm_cmsis
    URL https://codeload.github.com/ARM-software/CMSIS_6/tar.gz/3c860f7a5810a34205bdbadb84b6d5f78f1cb322
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(st_hal st_device arm_cmsis)

set(device_templates "${st_device_SOURCE_DIR}/Source/Templates")
set(hal "${st_hal_SOURCE_DIR}/Src/stm32${family}xx_hal")
if(STM32_BOARD STREQUAL "NUCLEO_G474RE")
    set(linker_script "${CMAKE_CURRENT_SOURCE_DIR}/board/stm32g474re_flash.ld")
else()
    set(linker_script "${device_templates}/gcc/linker/STM32H533xx_FLASH.ld")
endif()
string(TOLOWER "${device}" startup_device)
set(firmware "ece2_project_d_${board_suffix}")
set(target "${firmware}.elf")
add_executable(${target}
    board/main.c
    "${device_templates}/system_stm32${family}xx.c"
    "${device_templates}/gcc/startup_${startup_device}.s"
    "${hal}.c" "${hal}_cortex.c" "${hal}_gpio.c" "${hal}_rcc.c" "${hal}_rcc_ex.c"
    "${hal}_spi.c" "${hal}_uart.c" "${hal}_dma.c")
target_include_directories(${target} PRIVATE board
    "${st_hal_SOURCE_DIR}/Inc" "${st_device_SOURCE_DIR}/Include" "${arm_cmsis_SOURCE_DIR}/CMSIS/Core/Include")
target_compile_definitions(${target} PRIVATE ${device} USE_HAL_DRIVER)
target_compile_options(${target} PRIVATE -ffunction-sections -fdata-sections)
target_link_libraries(${target} PRIVATE audio_core)
target_link_options(${target} PRIVATE --specs=nano.specs --specs=nosys.specs
    "-T${linker_script}" -Wl,--gc-sections "-Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${firmware}.map")
set_property(TARGET ${target} APPEND PROPERTY LINK_DEPENDS "${linker_script}")
find_program(ARM_OBJCOPY arm-none-eabi-objcopy REQUIRED)
add_custom_command(TARGET ${target} POST_BUILD
    COMMAND "${ARM_OBJCOPY}" -O ihex $<TARGET_FILE:${target}> "${CMAKE_CURRENT_BINARY_DIR}/${firmware}.hex"
    VERBATIM)
