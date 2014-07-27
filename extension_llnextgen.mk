TOSOURCE.g = $(patsubst %.g,.objects/%.c,$(1))
TOHEADER.g = $(patsubst %.g,.objects/%.h,$(1))
TOOBJECTBASE.g = $(patsubst %.g,%,$(1))
TARGETS.g = .objects/%.c .objects/%.h
COMPILE.g = LLnextgen --base-name=.objects/$$* $$<
DISPLAYNAME.g = LLNEXTGEN

TOSOURCE.gg = $(patsubst %.gg,.objects/%.cc,$(1))
TOHEADER.gg = $(patsubst %.gg,.objects/%.h,$(1))
TOOBJECTBASE.gg = $(patsubst %.gg,%,$(1))
TARGETS.gg = .objects/%.cc .objects/%.h
COMPILE.gg = LLnextgen --base-name=.objects/$$* --extensions=cc,h $$<
DISPLAYNAME.gg = LLNEXTGEN

EXTENSIONS += g gg
