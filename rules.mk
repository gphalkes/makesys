# Common Makefile part.
# Usage:
# Define the following variables, then include this file:
#
# TARGETS          The names of all C targets to be built from sources
# CXXTARGETS       The names of all C++ targets to be built from sources
# EXTRATARGETS     The names of all targets for which custom rules are used
# CFLAGS           Flags for the C compiler, used for all compiles
# LDFLAGS          Flags for the linker, used for all compiles
# LDLIBS           Libraries to link, used for all compiles
# LCFLAGS          Flags for the C compiler, only for libtool compiles
# CFILES.<target>  The list of C files for target <target>
# LFILES.<target>  The list of lex files for target <target>
# GFILES.<target>  The list of LLnextgen grammar files for target <target>
# LCFILES.<target> The list of C files for _library_ target <target>
# CFLAGS.<stem>    Flags for the C compiler, used for <stem>.c only
# LDFLAGS.<target> Flags for the linker, used for <target> only
# LDLIBS.<target>  Libraries to link, used for <target> only
#
# Notes:
# - Library targets should be specified as lib*.la, not as lib*.so. This will
#   ensure that they are built using libtool.
# - Any custom rules should be defined after including this file, as this file
#   defines the all rule which should be the first rule in the Makefile
# - Extra dependencies can be defined after inclusion of this file. If only
#   the order is important, use an order only dependency: "test: | libX.la"

ifndef TARGETS
ifndef CXXTARGETS
$(error TARGETS nor CXXTARGETS defined. See $(lastword $(MAKEFILE_LIST)) for details)
endif
endif

ifndef VERBOSE
_VERBOSE_CC = @echo [CC] $< ;
_VERBOSE_CCLT = @echo [CCLT] $< ;
_VERBOSE_LD = @echo [LD] $@ ;
_VERBOSE_LDLT = @echo [LDLT] $@ ;
_VERBOSE_SILENT = --silent
_VERBOSE_GEN = @echo [GEN] $@ ;
_VERBOSE_CXX = @echo [CXX] $< ;
endif

MKPATH:=$(dir $(lastword $(MAKEFILE_LIST)))

VERSION?=debug
CC:=gcc
CXX:=g++
SHELL:=/bin/bash

ifdef COVERAGE
	COVERAGEFLAGS:=-fprofile-arcs -ftest-coverage
endif
ifdef PROFILE
	PROFILEFLAGS:=-pg
endif
ifeq ($(VERSION),debug)
	CFLAGS:=-Wall -W -ggdb -DDEBUG -Wswitch-default \
		-Wcast-align -Wbad-function-cast \
		-Wcast-qual -Wwrite-strings -Wstrict-prototypes \
		$(COVERAGEFLAGS) $(PROFILEFLAGS) $(ANSIFLAGS) -pipe
	CXXFLAGS:=-Wall -W -ggdb -DDEBUG -Wswitch-default \
		-Wshadow -Wcast-align -Wcast-qual -Wwrite-strings \
		$(COVERAGEFLAGS) $(PROFILEFLAGS) -pipe
else
	CFLAGS:=-Wall -W $(ANSIFLAGS) -O2 -pipe
	CXXFLAGS:=-Wall -W $(ANSIFLAGS) -O2 -pipe
endif
GSTLFILTOPTS := -banner:no -width:0

.PHONY: all clean

all: $(TARGETS) $(CXXTARGETS) $(EXTRATARGETS)

CFILES:= $(foreach PART, $(TARGETS) $(CXXTARGETS), $(CFILES.$(PART)))
GFILES:= $(foreach PART, $(TARGETS) $(CXXTARGETS), $(GFILES.$(PART)))
LFILES:= $(foreach PART, $(TARGETS) $(CXXTARGETS), $(LFILES.$(PART)))
LCFILES:= $(foreach PART, $(TARGETS) $(CXXTARGETS), $(LCFILES.$(PART)))
CXXFILES:= $(foreach PART, $(CXXTARGETS), $(CXXFILES.$(PART)))
SOURCES:= $(CFILES) $(GFILES) $(LFILES) $(LCFILES) $(CXXFILES)

# force use of our pattern rule for lex files
$(foreach FILE, $(LFILES), $(eval $(patsubst %.l, .objects/%.o, $(FILE)): $(patsubst %.l, .objects/%.c,$(FILE))))

OBJECTS:=$(patsubst %.c, .objects/%.o, $(CFILES)) \
	$(patsubst %.l, .objects/%.o, $(LFILES)) \
	$(patsubst %.g, .objects/%.o, $(GFILES)) \
	$(patsubst %.c, .objects/%.lo, $(LCFILES)) \
	$(patsubst %.cc, .objects/%.o, $(CXXFILES))
$(foreach PART, $(TARGETS) $(CXXTARGETS), $(eval OBJECTS.$(PART):= \
	$$(patsubst %.c, .objects/%.o, $$(CFILES.$(PART))) \
	$$(patsubst %.g, .objects/%.o, $$(GFILES.$(PART))) \
	$$(patsubst %.l, .objects/%.o, $$(LFILES.$(PART))) \
	$$(patsubst %.c, .objects/%.lo, $$(LCFILES.$(PART))) \
	$$(patsubst %.cc, .objects/%.o, $$(CXXFILES.$(PART)))))
DEPENDENCIES:= $(patsubst %, .deps/%, $(SOURCES))

$(foreach PART, $(filter-out lib%.la, $(TARGETS)), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LD) $$(CC) $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART))))

$(foreach PART, $(filter-out lib%.la, $(CXXTARGETS)), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LD) $$(CXX) $$(CXXFLAGS) $$(CXXFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART))))

$(foreach PART, $(filter lib%.la, $(TARGETS)), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(_VERBOSE_LDLT) libtool $(_VERBOSE_SILENT) --mode=link $$(CC) $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART)) -rpath /usr/lib))
# Add dependency rules for grammar files. Header files generated from grammar
# files are needed by the lexical analyser and other files
$(foreach FILE, $(GFILES), $(if $(DEPS.$(FILE)), $(eval $(patsubst %.c, %.o, $(patsubst %.l, %.c, $(patsubst %, .objects/%, $(DEPS.$(FILE))))): $(patsubst %.g, .objects/%.h, $(FILE)))))

.objects/%.o: %.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CC) $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) -c $< -o $@

.objects/%.o: .objects/%.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CC) $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) -c $< -o $@

.objects/%.lo: %.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.lo: .objects/%.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CCLT) libtool --mode=compile $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.c .objects/%.h: %.g
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	LLnextgen --base-name=.objects/$* $<

.objects/%.c: %.l
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	flex -o $@ $<

.objects/%.o: %.cc
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CXX) set -o pipefail ; $(CXX) -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) -c $< -o $@ 2>&1 | $(MKPATH)/gSTLFilt.pl $(GSTLFILTOPTS)

clean::
	rm -rf $(TARGETS) $(CXXTARGETS) .deps .objects .libs >/dev/null 2>&1

-include $(DEPENDENCIES)
