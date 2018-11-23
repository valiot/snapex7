
# Variables to override
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_LIBDIR path to libei.a
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

# Look for the EI library and header files
# For crosscompiled builds, ERL_EI_INCLUDE_DIR and ERL_EI_LIBDIR must be
# passed into the Makefile.


# ifeq ($(OS),)
# OS = unix
# endif

# ifeq ($(TARGET),)
# TARGET = arm_v6_linux
# endif

# OS_PATH = /build/$(OS)

SNAP7_PATH = src/snap7
S7_H_PATH = /examples/plain-c

ifeq ($(ERL_EI_INCLUDE_DIR),)
ERL_ROOT_DIR = $(shell erl -eval "io:format(\"~s~n\", [code:root_dir()])" -s init stop -noshell)
ifeq ($(ERL_ROOT_DIR),)
   $(error Could not find the Erlang installation. Check to see that 'erl' is in your PATH)
endif
ERL_EI_INCLUDE_DIR = "$(ERL_ROOT_DIR)/usr/include"
ERL_EI_LIBDIR = "$(ERL_ROOT_DIR)/usr/lib"
endif
# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei
LDFLAGS +=
CFLAGS += -std=gnu99
# Enable for debug messages
CFLAGS += -DDEBUG
# CC ?= $(CROSSCOMPILER)-gcc
# #CC = /home/alde/.nerves/artifacts/nerves_toolchain_armv6_rpi_linux_gnueabi-linux_x86_64-1.1.0/bin/armv6-rpi-linux-gnueabi-gcc
# CCP=g++
# AR       := ar rcus

# SRC = $(wildcard src/*.c) 
# SRC_PATH = src
# OBJ = $(SRC:.c=.o)


# .PHONY: all clean

# all: snap7 priv/snap7

## seleccionar arquitectura
TargetCPU  :=arm_v6
OS         :=linux
CXXFLAGS   := -O3 -g -fPIC -pedantic

##
## Common variables (CXXFLAGS varies across platforms)
##
AR       := ar rcus
CC ?= $(CROSSCOMPILER)-gcc
CXX ?= $(CROSSCOMPILER)-g++

#
# Common for every unix flavour (any changes will be reflected on all platforms)
#
Platform               :=$(TargetCPU)-$(OS)
ConfigurationName      :=Release
IntermediateDirectory  :=src/snap7/build/temp/$(TargetCPU)
OutDir                 := $(IntermediateDirectory)
SharedObjectLinkerName :=-shared -fPIC
DebugSwitch            :=-gstab
IncludeSwitch          :=-I
LibrarySwitch          :=-l
OutputSwitch           :=-o 
LibraryPathSwitch      :=-L
PreprocessorSwitch     :=-D
SourceSwitch           :=-c 
OutputFile             :=src/snap7/build/bin/$(Platform)/libsnap.so
PreprocessOnlySwitch   :=-E 
ObjectsFileList        :="filelist.txt"
MakeDirCommand         :=mkdir -p
LinkOptions            :=  -O3
IncludePath            :=  $(IncludeSwitch)src/snap7/build/unix $(IncludeSwitch)src/snap7/src/sys $(IncludeSwitch)src/snap7/src/core $(IncludeSwitch)src/snap7/src/lib 
Libs                   := $(LibrarySwitch)pthread $(LibrarySwitch)rt 
LibPath                := $(LibraryPathSwitch)src/snap7/build/unix
LibInstall             := priv	

##
## User defined environment variables
##
Objects0=$(IntermediateDirectory)/sys_snap_msgsock.o $(IntermediateDirectory)/sys_snap_sysutils.o $(IntermediateDirectory)/sys_snap_tcpsrvr.o $(IntermediateDirectory)/sys_snap_threads.o $(IntermediateDirectory)/core_s7_client.o $(IntermediateDirectory)/core_s7_isotcp.o $(IntermediateDirectory)/core_s7_partner.o $(IntermediateDirectory)/core_s7_peer.o $(IntermediateDirectory)/core_s7_server.o $(IntermediateDirectory)/core_s7_text.o \
	$(IntermediateDirectory)/core_s7_micro_client.o $(IntermediateDirectory)/lib_snap7_libmain.o 

Objects=$(Objects0) 

SRC = $(wildcard src/*.c) 
SRC_PATH = src
OBJ = $(SRC:.c=.o)

##
## Main Build Targets 
##
.PHONY: all clean PreBuild PostBuild 
all: snap7 priv/snap7

snap7: $(OutputFile)

$(OutputFile): $(IntermediateDirectory)/.d $(Objects)
	@$(MakeDirCommand) $(LibInstall) 
	@$(MakeDirCommand) $(@D)
	@$(MakeDirCommand) $(IntermediateDirectory)
	@echo $(Objects0)  > $(ObjectsFileList)
	$(CXX) $(SharedObjectLinkerName) $(OutputSwitch)$(OutputFile) @$(ObjectsFileList) $(LibPath) $(Libs) $(LinkOptions)
	$(RM) $(ObjectsFileList)
	cp -f $(OutputFile) $(LibInstall)

$(IntermediateDirectory)/.d:
	@test -d src/snap7/build/temp/$(TargetCPU) || $(MakeDirCommand) src/snap7/build/temp/$(TargetCPU)

##
## Objects
##

$(IntermediateDirectory)/sys_snap_msgsock.o: 
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_msgsock.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/sys_snap_msgsock.o $(IncludePath)

$(IntermediateDirectory)/sys_snap_sysutils.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_sysutils.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/sys_snap_sysutils.o $(IncludePath)

$(IntermediateDirectory)/sys_snap_tcpsrvr.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_tcpsrvr.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/sys_snap_tcpsrvr.o $(IncludePath)

$(IntermediateDirectory)/sys_snap_threads.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_threads.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/sys_snap_threads.o $(IncludePath)

$(IntermediateDirectory)/core_s7_client.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_client.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_client.o $(IncludePath)

$(IntermediateDirectory)/core_s7_isotcp.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_isotcp.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_isotcp.o $(IncludePath)

$(IntermediateDirectory)/core_s7_partner.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_partner.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_partner.o $(IncludePath)

$(IntermediateDirectory)/core_s7_peer.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_peer.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_peer.o $(IncludePath)

$(IntermediateDirectory)/core_s7_server.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_server.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_server.o $(IncludePath)

$(IntermediateDirectory)/core_s7_text.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_text.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_text.o $(IncludePath)

$(IntermediateDirectory)/core_s7_micro_client.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_micro_client.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/core_s7_micro_client.o $(IncludePath)

$(IntermediateDirectory)/lib_snap7_libmain.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/lib/snap7_libmain.cpp" $(CXXFLAGS) -o $(IntermediateDirectory)/lib_snap7_libmain.o $(IncludePath)

priv/snap7: $(OBJ) 
	@echo $(OBJ)
	#$(CC) -O3 src/erlcmd.o src/s7_client.o src/util.o -L$(SRC_PATH) -I$(SRC_PATH) -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o priv/s7_client.o
	$(CC) -O3 src/erlcmd.o src/s7_client.o src/util.o -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o priv/s7_client.o
	$(CC) -O3 src/erlcmd.o src/s7_server.o src/util.o -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o priv/s7_server.o
	$(CC) -O3 src/erlcmd.o src/s7_partner.o src/util.o -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o priv/s7_partner.o

%.o:%.c
	@echo debug1: $^
	$(CC) -c $(ERL_CFLAGS) -I$(SNAP7_PATH)$(S7_H_PATH) -L$(LibInstall) -I$(LibInstall) $(CFLAGS) -o $@ $<

##
## Clean / Install
##

clean:
	$(RM) $(IntermediateDirectory)/*.o
	$(RM) $(OutputFile)
	rm -f priv/*.o src/*.o src/*.so src/*.o
	rm -rf priv
	

