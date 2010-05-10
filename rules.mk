# Common Makefile part.
# Usage:
# Define the following variables, then include this file:
#
# TARGETS          The names of all targets to be built from sources
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
$(error TARGETS not defined. See $(lastword $(MAKEFILE_LIST)) for details)
endif

.PHONY: all clean

all: $(TARGETS) $(EXTRATARGETS)

CFILES:= $(foreach PART, $(TARGETS), $(CFILES.$(PART)))
GFILES:= $(foreach PART, $(TARGETS), $(GFILES.$(PART)))
LFILES:= $(foreach PART, $(TARGETS), $(LFILES.$(PART)))
LCFILES:= $(foreach PART, $(TARGETS), $(LCFILES.$(PART)))
SOURCES:= $(CFILES) $(GFILES) $(LFILES) $(LCFILES)

# force use of our pattern rule for lex files
$(foreach FILE, $(LFILES), $(eval $(patsubst %.l, .objects/%.o, $(FILE)): $(patsubst %.l, .objects/%.c,$(FILE))))

OBJECTS:=$(patsubst %.c, .objects/%.o, $(CFILES)) \
	$(patsubst %.l, .objects/%.o, $(LFILES)) \
	$(patsubst %.g, .objects/%.o, $(GFILES)) \
	$(patsubst %.c, .objects/*.lo, $(LCFILES))
$(foreach PART, $(TARGETS), $(eval OBJECTS.$(PART):= \
	$$(patsubst %.c, .objects/%.o, $$(CFILES.$(PART))) \
	$$(patsubst %.g, .objects/%.o, $$(GFILES.$(PART))) \
	$$(patsubst %.l, .objects/%.o, $$(LFILES.$(PART))) \
	$$(patsubst %.c, .objects/%.lo, $$(LCFILES.$(PART)))))
DEPENDENCIES:= $(patsubst %, .deps/%, $(SOURCES))

$(foreach PART, $(filter-out lib%.la, $(TARGETS)), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	$$(CC) $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART))))

$(foreach PART, $(filter lib%.la, $(TARGETS)), $(eval $(PART): $$(OBJECTS.$(PART)) ; \
	libtool --mode=link $$(CC) $$(CFLAGS) $$(CFLAGS.$(PART)) $$(LDFLAGS) $$(LDFLAGS.$(PART)) \
		-o $$@ $$^ $$(LDLIBS) $$(LDLIBS.$(PART)) -rpath /usr/lib))
# Add dependency rules for grammar files. Header files generated from grammar
# files are needed by the lexical analyser and other files
$(foreach FILE, $(GFILES), $(if $(DEPS.$(FILE)), $(eval $(patsubst %.c, %.lo, $(patsubst %.l, %.c, $(patsubst %, .objects/%, $(DEPS.$(FILE))))): $(patsubst %.g, .objects/%.h, $(FILE)))))

.objects/%.o: %.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) -c $< -o $@

.objects/%.o: .objects/%.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	$(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) -c $< -o $@

.objects/%.lo: %.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	libtool --mode=compile $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.lo: .objects/%.c
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	libtool --mode=compile $(CC) -MMD -MP -MF .deps/$< $(CFLAGS) $(CFLAGS.$*) $(LCFLAGS) -c $< -o $@
	@sed -i -r 's/\.o\>/\.lo/g' .deps/$<

.objects/%.c .objects/%.h: %.g
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	LLnextgen --base-name=.objects/$* $<

.objects/%.c: %.l
	@[ -d .deps/`dirname '$<'` ] || mkdir -p .deps/`dirname '$<'`
	@[ -d .objects/`dirname '$<'` ] || mkdir -p .objects/`dirname '$<'`
	flex -o $@ $<

clean::
	rm -rf $(TARGETS) .deps .objects .libs >/dev/null 2>&1

-include $(DEPENDENCIES)
