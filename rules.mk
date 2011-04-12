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
# LDFLAGS.<target> Flags for the linker, used for <target> only
# LDLIBS.<target>  Libraries to link, used for <target> only
# EXTRATARGETS     The names of all targets for which custom rules are used
#
# Notes:
# - Library targets should be specified as lib*.la, not as lib*.so.
# - Any custom rules should be defined after including this file, as this file
#   defines the "all" rule which should be the first rule in the Makefile
# - Extra dependencies can be defined after inclusion of this file. If only
#   the order is important, use an order only dependency: "test: | libX.la"

ifeq ($(strip $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS)),)
$(error No TARGETS, CXXTARGETS, LTTARGETS or CXXLTTARGETS defined. See $(lastword $(MAKEFILE_LIST)) for details)
endif

ifndef VERBOSE
_VERBOSE_CC = @echo '[CC]' $< ;
_VERBOSE_CCLT = @echo '[CCLT]' $< ;
_VERBOSE_LD = @echo '[LD]' $@ ;
_VERBOSE_LDLT = @echo '[LDLT]' $@ ;
_VERBOSE_SILENT = --silent
_VERBOSE_GEN = @echo '[GEN]' $@ ;
_VERBOSE_CXX = @echo '[CXX]' $< ;
_VERBOSE_LEX = @echo '[LEX]' $< ;
_VERBOSE_LLNEXTGEN = @echo '[LLNEXTGEN]' $< ;
_VERBOSE_PRINT = --no-print-directory
endif

MKPATH:=$(dir $(lastword $(MAKEFILE_LIST)))

VERSION ?= debug
CC ?= gcc
CXX ?= g++
SHELL := /bin/bash

ifdef COVERAGE
	COVERAGEFLAGS := -fprofile-arcs -ftest-coverage
endif
ifdef PROFILE
	PROFILEFLAGS := -pg
endif
ifeq ($(VERSION),debug)
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

all: $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS) $(EXTRATARGETS)

STDSOURCES:= $(foreach PART, $(TARGETS) $(CXXTARGETS), $(SOURCES.$(PART)))
LTSOURCES:= $(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(SOURCES.$(PART)))
SOURCES:= $(foreach PART, $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS), $(SOURCES.$(PART)))


# force use of our pattern rule for lex files
$(foreach FILE, $(LFILES), $(eval $(patsubst %.l, .objects/%.o, $(FILE)): $(patsubst %.l, .objects/%.c,$(FILE))))

OBJECTS:=$(foreach EXT, .c .l .g .cc .gg, $(patsubst %$(EXT), .objects/%.o, $(filter %$(EXT), $(STDSOURCES)))) \
	$(foreach EXT, .c .l .g .cc .gg, $(patsubst %$(EXT), .objects/%.lo, $(filter %$(EXT), $(LTSOURCES))))

$(foreach PART, $(TARGETS) $(CXXTARGETS), $(eval OBJECTS.$(PART):= \
	$$(foreach EXT, .c .l .g .cc .gg, $$(patsubst %$$(EXT), .objects/%.o, $$(filter %$$(EXT), $$(SOURCES.$$(PART)))))))
$(foreach PART, $(LTTARGETS) $(CXXLTTARGETS), $(eval OBJECTS.$(PART):= \
	$$(foreach EXT, .c .l .g .cc .gg, $$(patsubst %$$(EXT), .objects/%.lo, $$(filter %$$(EXT), $$(SOURCES.$$(PART)))))))

DEPENDENCIES:= $(patsubst %, .deps/%, $(SOURCES)) $(patsubst %.g, .deps/.objects/%.c, $(filter %.g, $(SOURCES))) \
	$(patsubst %.l, .deps/.objects/%.c, $(filter %.l, $(SOURCES))) $(patsubst %.gg, .deps/.objects/%.cc, $(filter %.gg, $(SOURCES)))

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

# Add dependency rules for grammar files. Header files generated from grammar
# files are needed by the lexical analyser and other files
$(foreach FILE, $(filter %.g, $(SOURCES)), $(if $(DEPS.$(FILE)), $(eval $(patsubst %.c, %.o, $(patsubst %.l, %.c, \
	$(patsubst %, .objects/%, $(DEPS.$(FILE))))): $(patsubst %.g, .objects/%.h, $(FILE)))))
$(foreach FILE, $(filter %.gg, $(SOURCES)), $(if $(DEPS.$(FILE)), $(eval $(patsubst %.cc, %.o, $(patsubst %.l, %.c, \
	$(patsubst %, .objects/%, $(DEPS.$(FILE))))): $(patsubst %.gg, .objects/%.h, $(FILE)))))

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
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CC $(CC) -shared -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.lo: .objects/%.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CC $(CC) -shared -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.lo: %.cc
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CXX $(CXX) -shared -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) $(LCXXFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.lo: .objects/%.cc
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CCLT) libtool $(_VERBOSE_SILENT) --mode=compile --tag=CXX $(CXX) -shared -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) $(LCXXFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.c .objects/%.h: %.g
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_LLNEXTGEN) LLnextgen --base-name=.objects/$* $<

.objects/%.cc .objects/%.h: %.gg
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_LLNEXTGEN) LLnextgen --base-name=.objects/$* --extensions=cc,h $<

.objects/%.c: %.l
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_LEX) flex -o $@ $<

.objects/%.o: %.cc
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CXX) set -o pipefail ; $(CXX) -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) -c $< -o $@ $(GSTLFILT)

.objects/%.o: .objects/%.cc
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(_VERBOSE_CXX) set -o pipefail ; $(CXX) -MMD -MP -MF .deps/$< $(CXXFLAGS) $(CXXFLAGS.$*) -c $< -o $@ $(GSTLFILT)

# Block the implicit rule for lex files
%.c: %.l

.SECONDARY: $(patsubst %.l, .objects/%.c, $(filter %.l, $(SOURCES)))

clean::
	rm -rf $(TARGETS) $(CXXTARGETS) $(LTTARGETS) $(CXXLTTARGETS) .deps .objects .libs >/dev/null 2>&1

-include $(DEPENDENCIES)
