# NOTE: due to the way the output is specified for the protoc compiler, this
# extension does not work for proto files that are generated in .objects/.

TOSOURCE.proto = $(patsubst %.proto,.objects/%.pb.c,$(1))
TOHEADER.proto = $(patsubst %.proto,.objects/%.pb.h,$(1))
TOOBJECTBASE.proto = $(patsubst %.proto,%.pb,$(1))
TARGETS.proto = .objects/%.pb.c .objects/%.pb.h
COMPILE.proto = protoc -I. -I/usr/include --cpp_out=.objects $$<
DISPLAYNAME.proto = PROTOC

EXTENSIONS += proto
