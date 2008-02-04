# file:        Makefile
# author:      Andrea Vedaldi
# description: Build everything

NAME               := vlfeat
VER                := 0.9.1
DIST                = $(NAME)-$(VER)
#DEBUG              := yes

# --------------------------------------------------------------------
#                                                       Error messages
# --------------------------------------------------------------------

err_no_arch  =
err_no_arch +=$(shell echo "** Unknown host architecture '$(UNAME)'. This identifier"   1>&2)
err_no_arch +=$(shell echo "** was obtained by running 'uname -sm'. Edit the Makefile " 1>&2)
err_no_arch +=$(shell echo "** to add the appropriate configuration."                   1>&2)
err_no_arch +=Configuration failed


# --------------------------------------------------------------------
#                                  Architecture Identification Strings
# --------------------------------------------------------------------

Darwin_PPC_ARCH             := mac
Darwin_Power_Macintosh_ARCH := mac
Darwin_i386_ARCH            := mci
Linux_i386_ARCH             := glx
Linux_i686_ARCH             := glx
Linux_unknown_ARCH          := glx
Linux_x86_64_ARCH           := g64

# --------------------------------------------------------------------
#                                                        Configuration
# --------------------------------------------------------------------

# == PROGRAMS ==
#
# CC:          C compiler (e.g. gcc).
# MEX:         MEX compiler (e.g mex).
# LIBTOOL      libtool (used only under Mac)
# PYTHON:      Python interpreter (e.g. python)
#
# == LIBVL STATIC AND SHARED LIBRARY AND EXECUTABLE ==
#
# CLFAGS:      flags passed to $(CC) to compile an object file (*)
# LDFLAGS:     flags passed to $(CC) to create an executable file
#
# == MEX FILES ==
#
# MEX_BINDIR:  where to put mex files.
# MEX_FLAGS:   flags passed to $(MEX)
# MEX_CFLAGS:  flags added to the CLFAGS variable of $(MEX)
# MEX_LDFLAGS: flags added to the LDFLAGS variable of $(MEX)
#
# == AUTOMATIC CONFIGURATION ==
#
# BINDIR:         where to put the executable files.
# MEX_BINDIR:     where to put the MEX files.
# *_DLL_SUFFIX:   suffix of a DLL library (.dylib, .so, ...)
# *_MEX_SUFFIX:   suffix of a MEX file (.mexglx, .mexmac, ...)
#
# *_CFLAGS:       flags added to CLFAGS
# *_LDFLAGS:      flags added to LDFLAGS
# *_MEX_FLAGS:    flags added to MEX_FLAGS
# *_MEX_CFLAGS:   flags added to MEX_CLFAGS
# *_MEX_LDFLAGS:  flags added to MEX_LDFLAGS

MEX                 ?= mex
CC                  ?= cc
LIBTOOL             ?= libtool
PYTHON              ?= python

CFLAGS              += -I$(CURDIR) -pedantic -Wall -std=c89 -g -O0
CFLAGS              += -Wno-unused-function 
CFLAGS              += -Wno-long-long

LDFLAGS             +=

MEX_FLAGS            = -Itoolbox -L$(BINDIR) -lvl
MEX_CFLAGS           = $(CFLAGS)
MEX_LDFLAGS          =

UNAME               := $(shell uname -sm)
ARCH                := $($(shell echo "$(UNAME)" | tr \  _)_ARCH)

# Mac OS X on PPC processor
mac_BINDIR          := bin/mac
mac_DLL_SUFFIX      := dylib
mac_MEX_SUFFIX      := mexmac
mac_CFLAGS          := -Wno-variadic-macros -D__BIG_ENDIAN__ -gstabs+
mac_LDFLAGS         := -lm
mac_MEX_FLAGS       := -lm CC='gcc' CXX='g++' LD='gcc'
mac_MEX_CFLAGS      := 
mac_MEX_LDFLAGS     := 

# Mac OS X on Intel processor
mci_BINDIR          := bin/maci
mci_DLL_SUFFIX      := dylib
mci_MEX_SUFFIX      := mexmaci
mci_CFLAGS          := -Wno-variadic-macros -D__LITTLE_ENDIAN__ -gstabs+
mci_LDFLAGS         := -lm
mci_MEX_FLAGS       := -lm
mci_MEX_CFLAGS      := 
mci_MEX_LDFLAGS     := 

# Linux-32
glx_BINDIR          := bin/glx
glx_MEX_SUFFIX      := mexglx
glx_DLL_SUFFIX      := so
glx_CFLAGS          := -D__LITTLE_ENDIAN__ -std=c99
glx_LDFLAGS         := -lm
glx_MEX_FLAGS       := -lm
glx_MEX_CFLAGS      := 
glx_MEX_LDFLAGS     := -Wl,--rpath,\\\$$ORIGIN/

# Linux-64
g64_BINDIR          := bin/g64
g64_MEX_SUFFIX      := mexa64
g64_DLL_SUFFIX      := so
g64_CFLAGS          := -D__LITTLE_ENDIAN__ -std=c99 -fPIC
g64_LDFLAGS         := -lm
g64_MEX_FLAGS       := -lm
g64_MEX_CFLAGS      := 
g64_MEX_LDFLAGS     := -Wl,--rpath,\\\$$ORIGIN/

BINDIR              := $($(ARCH)_BINDIR)
DLL_SUFFIX          := $($(ARCH)_DLL_SUFFIX)
MEX_SUFFIX          := $($(ARCH)_MEX_SUFFIX)

CFLAGS              += $($(ARCH)_CFLAGS)
LDFLAGS             += $($(ARCH)_LDFLAGS)
MEX_FLAGS           += $($(ARCH)_MEX_FLAGS)
MEX_CFLAGS          += $($(ARCH)_MEX_CFLAGS)
MEX_LDFLAGS         += $($(ARCH)_MEX_LDFLAGS)

BINDIST             := $(DIST)-bin
MEX_BINDIR          := toolbox/$(MEX_SUFFIX)

# Print an error message if the architecture was not recognized.
ifeq ($(ARCH),)
die:=$(error $(err_no_arch))
endif

.PHONY : all
all : all-dir all-lib all-bin all-mex

# create auxiliary directories
.PHONY: all-dir
all-dir: results/.dirstamp doc/figures/demo/.dirstamp

# trick to make directories
.PRECIOUS: %/.dirstamp
%/.dirstamp :	
	mkdir -p $(dir $@)
	echo "Directory generated by make." > $@

# --------------------------------------------------------------------
#                                   Build static and dynamic libraries
# --------------------------------------------------------------------
#
# Objects are placed in the $(BINDIR)/objs/ directory. The makefile
# creates a static and a dynamic version of the library. Depending on
# the architecture, one or more of the following files are produced:
#
# $(OBJDIR)/libvl.a       Static library (UNIX)
# $(OBJDIR)/libvl.so      ELF dynamic library (Linux)
# $(OBJDIR)/libvl.dylib   Mach-O dynamic library (Mac OS X)
#
# == Note on Mac OS X ==
#
# On Mac we set the install name of the library to look in
# @loader_path/.  This means that any binary linked (either an
# executable or another DLL) will search in his own directory for a
# copy of libvl (this behaviour can then be changed by
# install_name_tool).

# We place the object and dependency files in $(BINDIR)/objs/ and
# the library in $(BINDIR)/libvl.a.

lib_src := $(wildcard vl/*.c)
lib_obj := $(notdir $(lib_src))
lib_obj := $(addprefix $(BINDIR)/objs/, $(lib_obj:.c=.o))
lib_dep := $(lib_obj:.o=.d)

# create library libvl.a
.PHONY: all-lib
all-lib: $(BINDIR)/libvl.a $(BINDIR)/libvl.$(DLL_SUFFIX)

.PRECIOUS: $(BINDIR)/objs/%.d

$(BINDIR)/objs/%.o : vl/%.c $(BINDIR)/objs/.dirstamp
	@echo "   CC '$<' ==> '$@'"
	@$(CC) $(CFLAGS) -c $< -o $@

$(BINDIR)/objs/%.d : vl/%.c $(BINDIR)/objs/.dirstamp
	@echo "   D  '$<' ==> '$@'"
	@$(CC) -M -MT '$(BINDIR)/objs/$*.o $(BINDIR)/objs/$*.d' $< -MF $@

$(BINDIR)/libvl.a : $(lib_obj)
	@echo "   A  '$@'"
	@ar rcs $@ $^

$(BINDIR)/libvl.dylib : $(lib_obj)
	@echo "DYLIB '$@'"
	@$(LIBTOOL) -dynamic                                  \
                    -flat_namespace                           \
                    -install_name @loader_path/libvl.dylib    \
	            -compatibility_version $(VER)             \
                    -current_version $(VER)                   \
	            -o $@ -undefined suppress $^

$(BINDIR)/libvl.so : $(lib_obj)
	@echo "   SO '$@'"
	@$(CC) $(CFLAGS) -shared $^ -o $@

ifeq ($(filter doc dox clean distclean info, $(MAKECMDGOALS)),)
include $(lib_dep) 
endif

# --------------------------------------------------------------------
#                                                       Build binaries
# --------------------------------------------------------------------
# We place the exacutables in $(BINDIR).

bin_src := $(wildcard src/*.c)
bin_tgt := $(notdir $(bin_src))
bin_tgt := $(addprefix $(BINDIR)/, $(bin_tgt:.c=))

.PHONY: all-bin
all-bin : $(bin_tgt)

$(BINDIR)/% : src/%.c $(BINDIR)/libvl.a src/generic-driver.h
	@echo "   CC '$<' ==> '$@'"
	@$(CC) $(CFLAGS) $(LDFLAGS) $< $(BINDIR)/libvl.a -o $@

# --------------------------------------------------------------------
#                                                      Build MEX files
# --------------------------------------------------------------------
# MEX files are placed in toolbox/$(MEX_SUFFIX). MEX files are linked
# so that they search for the dynamic libvl in the directory where
# they are found. A link is automatically created to the library
# binary file.
#
# On Linux, this is obtained by setting -rpath to $ORIGIN/ for each
# MEX file. On Mac OS X this is implicitly obtained since libvl.dylib
# has install_name relative to @loader_path/.

mex_src := $(shell find toolbox -name "*.c")
mex_tgt := $(addprefix $(MEX_BINDIR)/, \
	               $(notdir $(mex_src:.c=.$(MEX_SUFFIX)) ) )

.PHONY: all-mex
all-mex : $(mex_tgt)

vpath %.c $(shell find toolbox -type d)

$(MEX_BINDIR)/libvl.$(DLL_SUFFIX) :                   \
                 $(BINDIR)/libvl.$(DLL_SUFFIX)        \
                 $(MEX_BINDIR)/.dirstamp
	@test -h $@ || ln -sf ../../$(BINDIR)/$(notdir $<) $@

$(MEX_BINDIR)/%.$(MEX_SUFFIX) :                       \
                 %.c toolbox/mexutils.h               \
                  $(MEX_BINDIR)/libvl.$(DLL_SUFFIX)
	@echo "   MX '$<' ==> '$@'"
	@$(MEX) CFLAGS='$$CFLAGS  $(MEX_CFLAGS)'      \
		LDFLAGS='$$LDFLAGS $(MEX_LDFLAGS)'    \
	        $(MEX_FLAGS)                          \
	        $< -outdir $(dir $(@))

# --------------------------------------------------------------------
#                                                  Build documentation
# --------------------------------------------------------------------

m_src := $(shell find toolbox -name "*.m")

.PHONY: doc dox docdeep mdoc

doc:
	make -C doc all

docdeep: all
	cd toolbox ; \
	matlab -nojvm -nodesktop -r 'vlfeat_setup;demo_all;exit'

dox: VERSION
	make -C doc/figures all
	(test -e dox || mkdir dox)
	doxygen doc/doxygen.conf

.PHONY: modc
mdoc: doc/toolbox.html

doc/toolbox.html : $(m_src)
	perl mdoc.pl -o doc/toolbox.html toolbox

# --------------------------------------------------------------------
#                                                       Clean and dist
# --------------------------------------------------------------------

TIMESTAMP:
	echo "Version $(VER)"            > TIMESTAMP
	echo "Archive created on `date`" >>TIMESTAMP

VERSION:
	echo "$(VER)" > VERSION

.PHONY: clean
clean:
	make -C doc clean
	rm -rf `find ./bin -name 'objs' -type d`
	rm -f  `find . -name '*~'`
	rm -f  `find . -name '.DS_Store'`
	rm -f  `find . -name '.gdb_history'`
	rm -f  `find . -name '._*'`
	rm -rf  ./results
	rm -rf $(NAME)

.PHONY: distclean
distclean: clean
	make -C doc distclean
	rm -rf bin dox
	rm -f  doc/toolbox.html
	for i in mexmac mexmaci mexglx mexw32 mexa64 dll pdb ;      \
	do                                                          \
		rm -rf "toolbox/$${i}" ;                            \
	done
	rm -f  $(NAME)-*.tar.gz

.PHONY: $(NAME), dist, bindist

$(NAME): TIMESTAMP VERSION
	rm -rf $(NAME)
	git archive --prefix=$(NAME)/ HEAD | tar xvf -
	cp TIMESTAMP $(NAME)
	cp VERSION $(NAME)

dist: $(NAME)
	COPYFILE_DISABLE=1						                                \
	COPY_EXTENDED_ATTRIBUTES_DISABLE=1                            \
	tar czvf $(DIST).tar.gz $(NAME)

bindist: $(NAME) all doc
	cp -rp bin $(NAME)
	cp -rp doc $(NAME)
	for i in mexmaci mexmac mexw32 mexglx mexa64 dll ;            \
	do                                                            \
		find toolbox -name "*.$${i}" -exec cp -p "{}" "$(NAME)/{}" \; ;\
	done
	COPYFILE_DISABLE=1						                                \
	COPY_EXTENDED_ATTRIBUTES_DISABLE=1                            \
	tar czvf $(BINDIST).tar.gz                                    \
	    --exclude "objs"                                          \
			$(NAME)

.PHONY: post, post-doc

HOST:=ganesh.cs.ucla.edu:/var/www/vlfeat/
post:
	scp $(DIST).tar.gz $(BINDIST).tar.gz \
	   $(HOST)/download

post-doc: doc
	rsync -rv doc/vlfeat-dox -e "ssh" \
	   $(HOST)

.PHONY: autorights
autorights: distclean
	autorights \
	  tooblox vl \
	  --recursive    \
	  --verbose \
	  --template doc/copylet.txt \
	  --years 2007   \
	  --authors "Andrea Vedaldi and Brian Fulkerson" \
	  --holders "Andrea Vedaldi and Brian Fulkerson" \
	  --program "VLFeat"

# --------------------------------------------------------------------
#                                                       Debug Makefile
# --------------------------------------------------------------------

.PHONY: info
info :
	@echo "lib_src ="
	@echo $(lib_src) 
	@echo "lib_obj ="
	@echo $(lib_obj) 
	@echo "lib_dep ="
	@echo $(lib_dep) 
	@echo "mex_src ="
	@echo $(mex_src) 
	@echo "mex_tgt ="
	@echo $(mex_tgt) 
	@echo "bin_src ="
	@echo $(bin_src) 
	@echo "bin_tgt ="
	@echo $(bin_tgt)
	@echo "ARCH         = $(ARCH)"
	@echo "DIST         = $(DIST)"
	@echo "BINDIST      = $(BINDIST)"
	@echo "MEX_BINDIR   = $(MEX_BINDIR)"
	@echo "DLL_SUFFIX   = $(DLL_SUFFIX)"
	@echo "MEX_SUFFIX   = $(MEX_SUFFIX)"
	@echo "CFLAGS       = $(CFLAGS)"
	@echo "LDFLAGS      = $(LDFLAGS)"
	@echo "MEX_FLAGS    = $(MEX_FLAGS)"
	@echo "MEX_CFLAGS   = $(MEX_CFLAGS)"
	@echo 'MEX_LDFLAGS  = $(MEX_LDFLAGS)'

# --------------------------------------------------------------------
#                                                        Xcode Support
# --------------------------------------------------------------------

.PHONY: dox-
dox- : dox

.PHONY: dox-clean
dox-clean:
