
# Makefile targets:
#
# all/install   build and install the NIF
# clean         clean build products and intermediates
#
# Variables to override:
#
# BUILD         where to store intermediate files (defaults to src directory)
# PREFIX        path to the installation direction (defaults to ./priv)
#
# CC            		C compiler
# CROSSCOMPILE			crosscompiler prefix, if any
# CFLAGS				compiler flags for compiling all C files
# ERL_CFLAGS			additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR 	include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR 		path to libei.a (Required for crosscompile)
# LDFLAGS				linker flags for linking all binaries
# ERL_LDFLAGS			additional linker flags for projects referencing Erlang libraries

ifeq ($(MIX_COMPILE_PATH),)
	$(error MIX_COMPILE_PATH should be set by elixir_make!)
endif

PREFIX = $(MIX_COMPILE_PATH)/../priv
BUILD  = $(MIX_COMPILE_PATH)/../obj

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
## Snap7 config options and dirs
##
CXXFLAGS   			   := -O3 -fPIC -pedantic
Platform               :=$(TargetCPU)-$(OS)
ConfigurationName      :=Release
IntermediateDirectory  :=$(BUILD)
OutDir                 :=$(IntermediateDirectory)
SharedObjectLinkerName :=-shared -fPIC
DebugSwitch            :=-gstab
IncludeSwitch          :=-I
OutputSwitch           :=-o 
LibraryPathSwitch      :=-L
PreprocessorSwitch     :=-D
SourceSwitch           :=-c
OutputFile             :=$(PREFIX)/libsnap.$(LibExt)
PreprocessOnlySwitch   :=-E 
ObjectsFileList        :="filelist.txt"
MakeDirCommand         :=mkdir -p
LinkOptions            :=  -O3
IncludePath            :=  $(IncludeSwitch)src/snap7/build/unix $(IncludeSwitch)src/snap7/src/sys $(IncludeSwitch)src/snap7/src/core $(IncludeSwitch)src/snap7/src/lib 
LibPath                := $(LibraryPathSwitch)src/snap7/build/unix
LibInstall             :=$(PREFIX)

##
## User defined environment variables
##
Objects = $(IntermediateDirectory)/sys_snap_msgsock.o $(IntermediateDirectory)/sys_snap_sysutils.o $(IntermediateDirectory)/sys_snap_tcpsrvr.o $(IntermediateDirectory)/sys_snap_threads.o $(IntermediateDirectory)/core_s7_client.o $(IntermediateDirectory)/core_s7_isotcp.o $(IntermediateDirectory)/core_s7_partner.o $(IntermediateDirectory)/core_s7_peer.o $(IntermediateDirectory)/core_s7_server.o $(IntermediateDirectory)/core_s7_text.o \
	$(IntermediateDirectory)/core_s7_micro_client.o $(IntermediateDirectory)/lib_snap7_libmain.o 

SNAPEX7_OUTPUT = $(LibInstall)/s7_client.o $(LibInstall)/s7_server.o $(LibInstall)/s7_partner.o

SRC_PATH = src

OBJ_SNAP7 = $(wildcard $(Objects): $(Occp)) 

OBJ_SNAPEX7 = $(wildcard $(LibInstall)/*.o: $(SRC_PATH)/*.c) 

SNAP7_PATH = src/snap7
S7_H_PATH = /examples/plain-c

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei
LDFLAGS +=
CFLAGS += -std=gnu99
CFLAGS += -DDEBUG


.PHONY: all clean 
all: $(OutputFile) $(OBJ_SNAPEX7) $(SNAPEX7_OUTPUT)

##
## SNAP7 OUTPUTS
##
$(OutputFile): $(Objects) 
	@$(MakeDirCommand) $(LibInstall) 
	@$(MakeDirCommand) $(@D)
	@
	@echo $(Objects)  > $(ObjectsFileList)
	$(CXX) $(SharedObjectLinkerName) $(OutputSwitch)$(OutputFile) @$(ObjectsFileList) $(LibPath) $(Libs) $(LinkOptions)
	$(RM) $(ObjectsFileList)

##
## SNAP7 Objects
##
$(IntermediateDirectory)/sys_snap_msgsock.o: 
	@test -d $(IntermediateDirectory) || $(MakeDirCommand) $(IntermediateDirectory)
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_msgsock.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/sys_snap_sysutils.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_sysutils.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/sys_snap_tcpsrvr.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_tcpsrvr.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/sys_snap_threads.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/sys/snap_threads.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_client.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_client.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_isotcp.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_isotcp.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_partner.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_partner.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_peer.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_peer.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_server.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_server.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_text.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_text.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/core_s7_micro_client.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/core/s7_micro_client.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

$(IntermediateDirectory)/lib_snap7_libmain.o:
	$(CXX) $(SourceSwitch) "src/snap7/src/lib/snap7_libmain.cpp" $(CXXFLAGS) -o $@ $(IncludePath)

##
## SNAPEX7 OBJECTS
##
$(PREFIX)/%.o: $(BUILD)/erlcmd.o $(BUILD)/%.o 
	@echo debug
	$(CC) -O3 $^ -L$(LibInstall) -I$(LibInstall) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o $@

$(BUILD)/%.o: $(SRC_PATH)/%.c
	@echo debug s7: $@, $^
	$(CC) -c $(ERL_CFLAGS) -I$(SNAP7_PATH)$(S7_H_PATH) -L$(LibInstall) -I$(LibInstall) $(CFLAGS) -o $@ $<

##
## Clean
##
clean:
	$(RM) $(IntermediateDirectory)/*.o
	$(RM) $(OutputFile)
	$(RM) -f $(LibInstall)/*.o  $(LibInstall)/*.so $(SRC_PATH)/*.o 
	$(RM) -rf $(LibInstall) $(IntermediateDirectory)
	

