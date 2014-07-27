# Copyright (c) 2013, G.P. Halkes
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Common Makefile part.
# Usage:
# Define the relevant of the following variables, then include this file:
#
# -- At least one of the following should be defined --
# TARGETS          The names of all C targets to be built from sources
# CXXTARGETS       The names of all C++ targets to be built from sources
# LTTARGETS        The names of all libtool C targets to be built from sources
# CXXLTTARGETS     The names of all libtool C++ targets to be built from sourcse
# -- These can be left empty, or can be appended to after inclusion of this file --
# CFLAGS           Flags for the C compiler, used for all compiles
# CXXFLAGS         Flags for the C++ compiler, used for all compiles
# LDFLAGS          Flags for the linker, used for all compiles
# LDLIBS           Libraries to link, used for all compiles
# LCFLAGS          Flags for the C compiler, only for libtool compiles
# LCXXFLAGS        Flags for the C++ compiler, only for libtool compiles
# -- SOURCES.<target> must be defined for each target listed --
# SOURCES.<target> The list of source files for the target <target>
# -- The following are completely optional --
# CFLAGS.<stem>    Flags for the C compiler, used for <stem>.c only
# CXXFLAGS.<stem>  Flags for the C++ compiler, used for <stem>.cc only
# TCFLAGS.<target> Flags for the C compiler, used for all files of the target
# TCXXFLAGS.<target>  Flags for the C++ compiler, used for all files of the target
# LDFLAGS.<target> Flags for the linker, used for <target> only
# LDLIBS.<target>  Libraries to link, used for <target> only
# FLFLAGS          Flags for flex
# EXTRATARGETS     The names of all targets for which custom rules are used
#
# Notes:
# - Library targets should be specified as lib*.la, not as lib*.so.
# - Any custom rules should be defined after including this file, as this file
#   defines the "all" rule which should be the first rule in the Makefile
# - Extra dependencies can be defined after inclusion of this file. If only
#   the order is important, use an order only dependency: "test: | libX.la"
# Use the L macro to refer to non-system library paths. This will ensure that
# both a -L option and a -Wl,-rpath are supplied. Only relative directories
# are supported. Multiple directories can be specified in a single call. E.g.:
# LDFLAGS = $(call L, ../src/.libs ../../libfoo/src/.libs)
#
# Defining extensions:
# It is possible to extend the set of rules for generating sources. To do this,
# define the following set of variables (functions):
# TOSOURCE.<ext>       Transform the argument to its final source files
# TOHEADER.<ext>       Transform the argument to its final header files
# TOOBJECTBASE.<ext>   Transform the argument to its final object files
# TARGETS.<ext>        Transform the argument to its direct targets (base on %.<ext>)
# COMPILE.<ext>        Compiler command (escape the $ expansions)
# DISPLAYNAME.<ext>    Name displayed when compiling in non-verbose mode
#
# Also, add "EXTENSIONS += <ext>" to register the extension.
# See one of the extension_*.mk files for examples.


ifeq ($(strip $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS)),)
$(error No TARGETS, CXXTARGETS, LTTARGETS or CXXLTTARGETS defined. See $(lastword $(MAKEFILE_LIST)) for details)
endif

ifndef VERBOSE
_VERBOSE = @echo '[$(strip $(1))]' $<;
_VERBOSE_CCLT = @echo '[CCLT]' $< ;
_VERBOSE_LD = @echo '[LD]' $@ ;
_VERBOSE_LDLT = @echo '[LDLT]' $@ ;
_VERBOSE_GEN = @echo '[GEN]' $@ ;
_VERBOSE_CXXLT = @echo '[CXXLT]' $< ;
_VERBOSE_SILENT = --silent
_VERBOSE_PRINT = --no-print-directory
endif

_GENDIR = @ [ -d $(1)/`dirname '$(2)'` ] || mkdir -p $(1)/`dirname '$(2)'`
GENOBJDIR = $(call _GENDIR,.objects,$<)
GENDEPDIR = $(call _GENDIR,.deps,$<)

MKPATH := $(dir $(lastword $(MAKEFILE_LIST)))
L = $(foreach d,$(1),-L$(d) -Wl,-rpath=$(CURDIR)/$(d))

BUILDVERSION ?= debug
ifeq ($(COMPILER),gcc)
CC := gcc
CXX := g++
else
ifneq ($(COMPILER),external)
CC := clang
CXX := clang++
endif
endif
SHELL := /bin/bash

ifdef COVERAGE
	COVERAGEFLAGS := -fprofile-arcs -ftest-coverage
endif
ifdef PROFILE
	CC := gcc
	CXX := g++
	PROFILEFLAGS := -pg
endif
ifeq ($(BUILDVERSION),debug)
	CFLAGS := -Wall -Wextra -ggdb -DDEBUG -Wswitch-default \
		-Wcast-align -Wbad-function-cast \
		-Wcast-qual -Wwrite-strings -Wstrict-prototypes \
		$(COVERAGEFLAGS) $(PROFILEFLAGS) $(ANSIFLAGS) -pipe
	CXXFLAGS := -Wall -W -ggdb -DDEBUG -Wswitch-default \
		-Wshadow -Wcast-align -Wcast-qual -Wwrite-strings \
		$(COVERAGEFLAGS) $(PROFILEFLAGS) -pipe
else
	CFLAGS := -Wall -Wextra $(ANSIFLAGS) -O2 -pipe $(PROFILEFLAGS)
	CXXFLAGS := -Wall -Wextra $(ANSIFLAGS) -O2 -pipe $(PROFILEFLAGS)
endif
CFLAGS += -I.
CXXFLAGS += -I.
LDFLAGS := -Wl,--no-undefined

# Compiler specific settings. G++ requires output filtering, and Clang can do without
# the caret stuff (switched on by VERBOSE)
ifeq ($(CXX),g++)
	GSTLFILTOPTS := -banner:no -width:0
	GSTLFILT := 2>&1 | $(MKPATH)/gSTLFilt.pl $(GSTLFILTOPTS)
else
	GSTLFILT :=
endif
ifndef VERBOSE
	ifeq ($(CC),clang)
		CFLAGS += -fno-caret-diagnostics
	endif
	ifeq ($(CXX),clang++)
		CXXFLAGS += -fno-caret-diagnostics
	endif
endif

.PHONY: all clean

ifneq ($(filter clean, $(MAKECMDGOALS)),)
all: clean
	@$(MAKE) --no-print-directory $(filter-out clean, $(MAKECMDGOALS))
else
all: $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS) $(EXTRATARGETS)
endif

STDSOURCES := $(foreach PART, $(TARGETS) $(CXXTARGETS), $(SOURCES.$(PART)))
LTSOURCES := $(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(SOURCES.$(PART)))
SOURCES := $(foreach PART, $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS), $(SOURCES.$(PART)))

TOSOURCE.c = $(1)
TOSOURCE.cc = $(1)
TOSOURCE.l = $(patsubst %.l,.objects/%.c,$(1))

TOHEADER.c =
TOHEADER.cc =
TOHEADER.l =

TOOBJECTBASE.c = $(patsubst %.c,%,$(1))
TOOBJECTBASE.cc = $(patsubst %.cc,%,$(1))
TOOBJECTBASE.l = $(patsubst %.l,%,$(1))

TARGETS.c = .objects/%.o
TARGETS.cc = .objects/%.o
TARGETS.l = .objects/%.c

COMPILE.c = $$(CC) -MMD -MP -MF .deps/$$< $$(CFLAGS) $$(CFLAGS.$$*) -c $$< -o $$@
COMPILE.cc = set -o pipefail ; $$(CXX) -MMD -MP -MF .deps/$$< $$(CXXFLAGS) $$(CXXFLAGS.$$*) -c $$< -o $$@ $$(GSTLFILT)
COMPILE.l = flex $$(FLFLAGS) -o $$@ $$<

DISPLAYNAME.c = CC
DISPLAYNAME.cc = CXX
DISPLAYNAME.l = LEX

EXTENSIONS += c cc l

# force use of our pattern rule for lex files
#$(foreach FILE, $(LFILES), $(eval $(patsubst %.l, .objects/%.o, $(FILE)): $(patsubst %.l, .objects/%.c,$(FILE))))

# Generate per target source, header and object lists
$(foreach PART, $(TARGETS) $(CXXTARGETS), $(eval _SOURCES.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOSOURCE.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), $$(FILE)))))
$(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(eval _SOURCES.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOSOURCE.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), $$(FILE)))))

$(foreach PART, $(TARGETS) $(CXXTARGETS), $(eval HEADERS.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOHEADER.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), $$(FILE)))))
$(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(eval HEADERS.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOHEADER.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), $$(FILE)))))

$(foreach PART, $(TARGETS) $(CXXTARGETS), $(eval OBJECTS.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOOBJECTBASE.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), .objects/$$(FILE).o))))
$(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(eval OBJECTS.$(PART) := \
	$$(foreach EXT, $(EXTENSIONS), $$(foreach FILE, $$(call TOOBJECTBASE.$$(EXT), $$(filter %.$$(EXT), $(SOURCES.$(PART)))), .objects/$$(FILE).lo))))

OBJECTS := $(foreach PART, $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS), $(OBJECTS.$(PART)))

# Linker rules
$(foreach PART, $(TARGETS), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LD) $$(CC) $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART))))

$(foreach PART, $(CXXTARGETS), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LD) $$(CXX) $$(CXXFLAGS) $$(CXXFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART))))

$(foreach PART, $(LTTARGETS), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LDLT) libtool $(_VERBOSE_SILENT) --mode=link --tag=CC $$(CC) -shared $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART)) -rpath /usr/lib))

$(foreach PART, $(CXXLTTARGETS), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LDLT) libtool $(_VERBOSE_SILENT) --mode=link --tag=CXX $$(CXX) -shared $$(CXXFLAGS) $$(CXXFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART)) -rpath /usr/lib))

# Add the per target CFLAGS/CXXFLAGS to each source file
$(foreach PART, $(CTARGETS) $(LTTARGETS), $(foreach FILE, $(filter %.c, $(_SOURCES.$(PART))), \
	$(eval CFLAGS.$(patsubst %.c,%, $(FILE)) += $$(TCFLAGS.$(PART)))))

$(foreach PART, $(CXXTARGETS) $(CXXLTTARGETS), $(foreach FILE, $(filter %.cc, $(_SOURCES.$(PART))), \
	$(eval CXXFLAGS.$(patsubst %.cc,%, $(FILE)) += $$(TCXXFLAGS.$(PART)))))

# Add dependency rules for generated header files
$(foreach PART, $(CTARGETS) $(LTTARGETS) $(CXXTARGETS) $(CXXLTTARGETS), $(eval $$(OBJECTS.$(PART)): $$(HEADERS.$(PART))))

.objects/%.lo: %.c
	$(GENDEPDIR)
	$(GENOBJDIR)
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CC $(CC) -shared -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/(\.libs\/)?([^/]+)\.o\>/\2\.lo/g' .deps/$<

.objects/%.lo: .objects/%.c
	$(GENDEPDIR)
	$(GENOBJDIR)
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CC $(CC) -shared -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/(\.libs\/)?([^/]+)\.o\>/\2\.lo/g' .deps/$<

.objects/%.lo: %.cc
	$(GENDEPDIR)
	$(GENOBJDIR)
	$(_VERBOSE_CXXLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CXX $(CXX) -shared -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) $(LCXXFLAGS) -c $< -o $@
	@sed -i -r 's/(\.libs\/)?([^/]+)\.o\>/\2\.lo/g' .deps/$<

.objects/%.lo: .objects/%.cc
	$(GENDEPDIR)
	$(GENOBJDIR)
	$(_VERBOSE_CXXLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CXX $(CXX) -shared -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) $(LCXXFLAGS) -c $< -o $@
	@sed -i -r 's/(\.libs\/)?([^/]+)\.o\>/\2\.lo/g' .deps/$<

define RULE_TEMPLATE
	$$(GENDEPDIR)
	$$(GENOBJDIR)
	$$(call _VERBOSE, $(call DISPLAYNAME.$(EXT))) $(COMPILE.$(EXT))
endef

$(foreach EXT, $(EXTENSIONS), $(eval $(TARGETS.$(EXT)): %.$(EXT); $(RULE_TEMPLATE)))
$(foreach EXT, $(EXTENSIONS), $(eval $(TARGETS.$(EXT)): .objects/%.$(EXT); $(RULE_TEMPLATE)))


# Block the implicit rule for lex files
%.c: %.l

.SECONDARY: $(patsubst %.l, .objects/%.c, $(filter %.l, $(SOURCES)))

clean::
	rm -rf $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS) .deps .objects .libs >/dev/null 2>&1

-include $(shell find .deps -type f 2>/dev/null)

