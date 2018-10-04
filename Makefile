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
ifeq ($(OS),)
OS = unix
endif

ifeq ($(TARGET),)
TARGET = arm_v6_linux
endif

OS_PATH = /build/$(OS)

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
CC ?= $(CROSSCOMPILER)-gcc

SRC = $(wildcard src/*.c) 
SRC_PATH = src
OBJ = $(SRC:.c=.o)

.PHONY: all clean

all: priv/snap7



priv/snap7: $(OBJ) snap7
	mkdir -p priv
	$(CC) -O3 -v $(OBJ) -L$(SRC_PATH) -I$(SRC_PATH) -lsnap $(ERL_LDFLAGS) $(LDFLAGS) -o $@

snap7:
	make -C $(SNAP7_PATH)$(OS_PATH) -f $(TARGET).mk install LibInstall=../../../libsnap.so

%.o:%.c
	@echo debug1: $^
	$(CC) -c $(ERL_CFLAGS) -I$(SNAP7_PATH)$(S7_H_PATH) $(CFLAGS) -o $@ $<

clean:
	rm -f priv/snap7 src/*.o src/*.so src/*.o
	make -C $(SNAP7_PATH)$(OS_PATH) -f $(TARGET).mk clean
