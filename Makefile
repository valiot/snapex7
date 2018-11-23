
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

##
## Snap7 OS and processor selector
##
LibrarySwitch	:=-l
ifeq ($(CC), $(filter $(CC), cc gcc))
ifeq ($(shell uname -s),Linux)
OS 				:=linux
Libs			:= $(LibrarySwitch)pthread $(LibrarySwitch)rt 
LibExt      	:=so
ifeq ($(shell uname -m), $(filter $(shell uname -m),x86_64 i386))   
TargetCPU  		:=$(shell uname -m)
else  
$(error processor not supported $(shell uname -m || echo))
endif 

else ifeq ($(shell uname -s ), Darwin)
OS 				:=osx
Libs 			:= $(LibrarySwitch)pthread
LibExt			:=dylib
ifeq ($(shell uname -m), $(filter $(shell uname -m),x86_64 i386))   
TargetCPU  		:=$(shell uname -m)
else  
$(error processor not supported $(shell uname -m || echo))
endif 

else
$(error OS not supported $(shell uname -s || echo))
endif

else
TargetCPU  		:=arm_v6
OS         		:=linux
Libs	   		:= $(LibrarySwitch)pthread $(LibrarySwitch)rt 
LibExt     		:=so
endif

##
## Common variables (CXXFLAGS varies across platforms), NERVES compatible
##
#CC ?= $(CROSSCOMPILER)-gcc
#CXX ?= $(CROSSCOMPILER)-g++
#
# Snap7 config options and dirs
#
CXXFLAGS   := -O3 -fPIC -pedantic
Platform               :=$(TargetCPU)-$(OS)
ConfigurationName      :=Release
IntermediateDirectory  :=src/snap7/build/temp/$(TargetCPU)
OutDir                 := $(IntermediateDirectory)
SharedObjectLinkerName :=-shared -fPIC
DebugSwitch            :=-gstab
IncludeSwitch          :=-I
OutputSwitch           :=-o 
LibraryPathSwitch      :=-L
PreprocessorSwitch     :=-D
SourceSwitch           :=-c 
OutputFile             :=src/snap7/build/bin/$(Platform)/libsnap.$(LibExt)
PreprocessOnlySwitch   :=-E 
ObjectsFileList        :="filelist.txt"
MakeDirCommand         :=mkdir -p
LinkOptions            :=  -O3
IncludePath            :=  $(IncludeSwitch)src/snap7/build/unix $(IncludeSwitch)src/snap7/src/sys $(IncludeSwitch)src/snap7/src/core $(IncludeSwitch)src/snap7/src/lib 
LibPath                := $(LibraryPathSwitch)src/snap7/build/unix
LibInstall             := priv

##
## User defined environment variables
##
Objects0=$(IntermediateDirectory)/sys_snap_msgsock.o $(IntermediateDirectory)/sys_snap_sysutils.o $(IntermediateDirectory)/sys_snap_tcpsrvr.o $(IntermediateDirectory)/sys_snap_threads.o $(IntermediateDirectory)/core_s7_client.o $(IntermediateDirectory)/core_s7_isotcp.o $(IntermediateDirectory)/core_s7_partner.o $(IntermediateDirectory)/core_s7_peer.o $(IntermediateDirectory)/core_s7_server.o $(IntermediateDirectory)/core_s7_text.o \
	$(IntermediateDirectory)/core_s7_micro_client.o $(IntermediateDirectory)/lib_snap7_libmain.o 

Objects=$(Objects0) 

SNAPEX7_OUTPUT = $(LibInstall)/s7_client.o $(LibInstall)/s7_server.o $(LibInstall)/s7_partner.o

OBJ_SNAP7 = $(wildcard $(IntermediateDirectory)/*.o) 
SRC_PATH = src
SRC = $(wildcard $(SRC_PATH)/*.c) 
OBJ_SNAPEX7 = $(SRC:.c=.o)

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


.PHONY: all clean 
all: $(OutputFile) $(OBJ_SNAPEX7) $(SNAPEX7_OUTPUT)

##
## SNAP7 OUTPUTS
##
$(OutputFile): $(OBJ_SNAP7) $(Objects)
	@echo debug: $@, $^
	@$(MakeDirCommand) $(LibInstall) 
	@$(MakeDirCommand) $(@D)
	@$(MakeDirCommand) $(IntermediateDirectory)
	@echo $(Objects0)  > $(ObjectsFileList)
	$(CXX) $(SharedObjectLinkerName) $(OutputSwitch)$(OutputFile) @$(ObjectsFileList) $(LibPath) $(Libs) $(LinkOptions)
	$(RM) $(ObjectsFileList)
	cp -f $(OutputFile) $(LibInstall)

##
## SNAP7 Objects
##
$(IntermediateDirectory)/sys_snap_msgsock.o: 
	@test -d src/snap7/build/temp/$(TargetCPU) || $(MakeDirCommand) src/snap7/build/temp/$(TargetCPU)
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

##
## SNAPEX7 OBJECTS
##
priv/%.o: src/%.o
	$(CC) -O3 src/erlcmd.o $^ src/util.o -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o $@

%.o:%.c
	@echo debug: $@, $^
	$(CC) -c $(ERL_CFLAGS) -I$(SNAP7_PATH)$(S7_H_PATH) -L$(LibInstall) -I$(LibInstall) $(CFLAGS) -o $@ $<

##
## Clean
##
clean:
	$(RM) $(IntermediateDirectory)/*.o
	$(RM) $(OutputFile)
	$(RM) -f $(LibInstall)/*.o  $(LibInstall)/*.so $(SRC_PATH)/*.o 
	$(RM) -rf $(LibInstall)
	

