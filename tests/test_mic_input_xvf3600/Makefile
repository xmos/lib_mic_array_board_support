# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = xvf3600_qf60

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = test_mic_input_xvf3600

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_mic_array lib_mic_array_board_support

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
COMMON_FLAGS = -O2 -g -report


XCC_FLAGS_4_MICS_SDR_SQ = $(COMMON_FLAGS) -DCOUNT=4 -DSQ_MIC_ARRAY=1
XCC_FLAGS_4_MICS_SDR_LIN = $(COMMON_FLAGS) -DCOUNT=4 -DSQ_MIC_ARRAY=0


# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 0

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
