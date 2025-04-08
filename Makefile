srcdir := /home/tgorlov/riscv-tools/riscv-gnu-toolchain
builddir := /home/tgorlov/riscv-tools/riscv-gnu-toolchain
INSTALL_DIR := /opt/riscv

GCC_SRCDIR := $(srcdir)/gcc
BINUTILS_SRCDIR := $(srcdir)/binutils
NEWLIB_SRCDIR := $(srcdir)/newlib
GLIBC_SRCDIR := $(srcdir)/glibc
MUSL_SRCDIR := $(srcdir)/musl
UCLIBC_SRCDIR := $(srcdir)/uclibc-ng
LINUX_HEADERS_SRCDIR := $(srcdir)/linux-headers/include
GDB_SRCDIR := $(srcdir)/gdb
QEMU_SRCDIR := $(srcdir)/qemu
SPIKE_SRCDIR := $(srcdir)/spike
PK_SRCDIR := $(srcdir)/pk
LLVM_SRCDIR := $(srcdir)/llvm
DEJAGNU_SRCDIR := $(srcdir)/dejagnu
DEBUG_INFO := 
ENABLE_DEFAULT_PIE := --disable-default-pie
DEJAGNU_SRCDIR := $(srcdir)/dejagnu

SIM ?= qemu

# Shared lib suffix
IS_DARWIN := $(shell uname -s | grep Darwin)
SHARED_LIB_SUFFIX := $(if $(IS_DARWIN),dylib,so)

ifeq ($(srcdir)/gcc,$(GCC_SRCDIR))
# We need a relative source dir for the gcc configure, to make msys2 mingw64
# builds work.  Mayberelsrcdir is relative if a relative path was used to run
# configure, otherwise absolute, so we have to check.
mayberelsrcdir := .
gccsrcdir := $(shell case $(mayberelsrcdir) in \
		  ([\\/]* | ?:[\\/]*)  echo $(mayberelsrcdir)/gcc ;; \
		  (*)  echo ../$(mayberelsrcdir)/gcc ;; \
		esac)
else
gccsrcdir := $(abspath $(GCC_SRCDIR))
endif

WITH_ARCH ?= --with-arch=rv64gc
WITH_ABI ?= --with-abi=lp64d
WITH_TUNE ?= --with-tune=rocket
WITH_ISA_SPEC ?= --with-isa-spec=20191213
SYSROOT := $(INSTALL_DIR)/sysroot
ENABLE_LIBSANITIZER ?= --disable-libsanitizer
QEMU_TARGETS ?= riscv64-linux-user,riscv32-linux-user

ENABLED_LANGUAGES ?= 
ifeq ($(ENABLED_LANGUAGES),)
	undefine ENABLED_LANGUAGES
endif

SHELL := /bin/sh
AWK := /usr/bin/gawk
SED := /usr/bin/sed
PATH := $(INSTALL_DIR)/bin:$(PATH)

# Check to see if we need wrapper scripts for awk/sed (which point to
# gawk/gsed on platforms where these aren't the default), otherwise
# don't override these as the wrappers don't always work.
ifneq (/usr/bin/sed, $(shell realpath $(shell which sed)))
	PATH := $(builddir)/scripts/wrapper/sed:$(PATH)
endif
ifneq (/usr/bin/gawk, $(shell realpath $(shell which awk)))
	PATH := $(builddir)/scripts/wrapper/awk:$(PATH)
endif

export PATH AWK SED

MULTILIB_FLAGS := --disable-multilib
MULTILIB_GEN := 
ifeq ($(MULTILIB_GEN),)
NEWLIB_MULTILIB_NAMES := rv64gc-lp64d
GCC_MULTILIB_FLAGS := $(MULTILIB_FLAGS)
else
NEWLIB_MULTILIB_NAMES := $(shell echo "$(MULTILIB_GEN)" | $(SED) 's/;/\n/g' | $(SED) '/^$$/d' | $(AWK) '{split($$0,a,"-"); printf "%s-%s", (NR==1?a[1]:" "a[1]),a[2]}')
GCC_MULTILIB_FLAGS := $(MULTILIB_FLAGS) --with-multilib-generator="$(MULTILIB_GEN)"
endif
GLIBC_MULTILIB_NAMES := rv64gc-lp64d
GCC_CHECKING_FLAGS := 

EXTRA_MULTILIB_TEST := 

XLEN := $(shell echo $(WITH_ARCH) | tr A-Z a-z | sed 's/.*rv\([0-9]*\).*/\1/')
ifneq ($(XLEN),32)
	XLEN := 64
endif

make_tuple = riscv$(1)-unknown-$(2)
LINUX_TUPLE  ?= $(call make_tuple,$(XLEN),linux-gnu)
NEWLIB_TUPLE ?= $(call make_tuple,$(XLEN),elf)
MUSL_TUPLE ?= $(call make_tuple,$(XLEN),linux-musl)
UCLIBC_TUPLE ?= $(call make_tuple,$(XLEN),linux-uclibc)

CFLAGS_FOR_TARGET := $(CFLAGS_FOR_TARGET_EXTRA) $(DEBUG_INFO)  -mcmodel=medlow
CXXFLAGS_FOR_TARGET := $(CXXFLAGS_FOR_TARGET_EXTRA) $(DEBUG_INFO)  -mcmodel=medlow
ASFLAGS_FOR_TARGET := $(ASFLAGS_FOR_TARGET_EXTRA) $(DEBUG_INFO) -mcmodel=medlow
# --with-expat is required to enable XML support used by OpenOCD.
BINUTILS_TARGET_FLAGS := --with-expat=yes $(BINUTILS_TARGET_FLAGS_EXTRA)
BINUTILS_NATIVE_FLAGS := $(BINUTILS_NATIVE_FLAGS_EXTRA)
GDB_TARGET_FLAGS := --with-expat=yes $(GDB_TARGET_FLAGS_EXTRA)
GDB_NATIVE_FLAGS := $(GDB_NATIVE_FLAGS_EXTRA)

GLIBC_TARGET_FLAGS := $(GLIBC_TARGET_FLAGS_EXTRA)
GLIBC_CC_FOR_TARGET ?= $(LINUX_TUPLE)-gcc
GLIBC_CXX_FOR_TARGET ?= $(LINUX_TUPLE)-g++
GLIBC_TARGET_BOARDS ?= $(shell $(srcdir)/scripts/generate_target_board \
  --sim-name riscv-sim \
  --cmodel $(shell echo -mcmodel=medlow | cut -d '=' -f2) \
  --build-arch-abi "$(GLIBC_MULTILIB_NAMES)" \
  --extra-test-arch-abi-flags-list "$(EXTRA_MULTILIB_TEST)")

NEWLIB_TARGET_FLAGS := $(NEWLIB_TARGET_FLAGS_EXTRA)
NEWLIB_CC_FOR_TARGET ?= $(NEWLIB_TUPLE)-gcc
NEWLIB_CXX_FOR_TARGET ?= $(NEWLIB_TUPLE)-g++
NEWLIB_TARGET_BOARDS ?= $(shell $(srcdir)/scripts/generate_target_board \
  --sim-name riscv-sim \
  --cmodel $(shell echo -mcmodel=medlow | cut -d '=' -f2) \
  --build-arch-abi "$(NEWLIB_MULTILIB_NAMES)" \
  --extra-test-arch-abi-flags-list "$(EXTRA_MULTILIB_TEST)")

NEWLIB_NANO_TARGET_BOARDS ?= $(shell $(srcdir)/scripts/generate_target_board \
  --sim-name riscv-sim-nano \
  --cmodel $(shell echo -mcmodel=medlow | cut -d '=' -f2) \
  --build-arch-abi "$(NEWLIB_MULTILIB_NAMES)" \
  --extra-test-arch-abi-flags-list "$(EXTRA_MULTILIB_TEST)")
NEWLIB_CC_FOR_MULTILIB_INFO := $(NEWLIB_CC_FOR_TARGET)

MUSL_TARGET_FLAGS := $(MUSL_TARGET_FLAGS_EXTRA)
MUSL_CC_FOR_TARGET ?= $(MUSL_TUPLE)-gcc
MUSL_CXX_FOR_TARGET ?= $(MUSL_TUPLE)-g++

UCLIBC_TARGET_FLAGS := $(UCLIBC_TARGET_FLAGS_EXTRA)
UCLIBC_CC_FOR_TARGET ?= $(UCLIBC_TUPLE)-gcc
UCLIBC_CXX_FOR_TARGET ?= $(UCLIBC_TUPLE)-g++

CONFIGURE_HOST   = 
PREPARATION_STAMP:=stamps/check-write-permission

all: newlib
ifeq (--disable-host-gcc,--enable-host-gcc)
PREPARATION_STAMP+= stamps/install-host-gcc
PATH := $(builddir)/install-host-gcc/bin:$(PATH)
GCC_CHECKING_FLAGS := $(GCC_CHECKING_FLAGS) --enable-werror-always
endif
newlib: stamps/build-gcc-newlib-stage2
linux: stamps/build-gcc-linux-stage2
musl: stamps/build-gcc-musl-stage2
uclibc: stamps/build-gcc-uclibc-stage2
ifeq (--enable-gdb,--enable-gdb)
newlib: stamps/build-gdb-newlib
linux: stamps/build-gdb-linux
musl: stamps/build-gdb-musl
endif
linux-native: stamps/build-gcc-linux-native
ifeq (--disable-llvm,--enable-llvm)
all: stamps/build-llvm-newlib
newlib: stamps/build-llvm-newlib
linux: stamps/build-llvm-linux
ifeq (--disable-multilib,--enable-multilib)
$(error "Setting multilib flags for LLVM builds is not supported.")
endif
endif

.PHONY: build-binutils build-gdb build-gcc1 build-libc build-gcc2 build-qemu build-llvm
build-binutils: stamps/build-binutils-newlib
build-gdb: stamps/build-gdb-newlib
build-gcc%: stamps/build-gcc-newlib-stage%
ifeq (newlib,linux)
build-libc: $(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
else
build-libc: stamps/build-newlib stamps/build-newlib-nano \
	stamps/merge-newlib-nano
endif
build-qemu: stamps/build-qemu
build-llvm: stamps/build-llvm-newlib

REGRESSION_TEST_LIST = gcc

.PHONY: check
check: check-newlib
.PHONY: check-linux check-newlib
check-linux: $(patsubst %,check-%-linux,$(REGRESSION_TEST_LIST))
check-newlib: $(patsubst %,check-%-newlib,$(REGRESSION_TEST_LIST))
check-newlib-nano: $(patsubst %,check-%-newlib-nano,$(REGRESSION_TEST_LIST))
.PHONY: check-gcc check-gcc-linux check-gcc-newlib check-gcc-newlib-nano
check-gcc: check-gcc-newlib
check-gcc-linux: stamps/check-gcc-linux
check-gcc-newlib: stamps/check-gcc-newlib
check-gcc-newlib-nano: stamps/check-gcc-newlib-nano
.PHONY: check-glibc-linux
check-glibc-linux: $(addprefix stamps/check-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
.PHONY: check-dhrystone check-dhrystone-linux check-dhrystone-newlib
check-dhrystone: check-dhrystone-newlib
.PHONY: check-binutils check-binutils-linux check-binutils-newlib
check-binutils: check-binutils-newlib
check-binutils-linux: stamps/check-binutils-linux
check-binutils-newlib: stamps/check-binutils-newlib
check-binutils-newlib-nano: stamps/check-binutils-newlib-nano
.PHONY: check-gdb check-gdb-linux check-gdb-newlib
check-gdb: check-gdb-newlib
check-gdb-linux: stamps/check-gdb-linux
check-gdb-newlib: stamps/check-gdb-newlib
check-gdb-newlib-nano: stamps/check-gdb-newlib-nano

.PHONY: report
report: report-newlib
.PHONY: report-linux report-newlib report-newlib-nano
report-linux: $(patsubst %,report-%-linux,$(REGRESSION_TEST_LIST))
report-newlib: $(patsubst %,report-%-newlib,$(REGRESSION_TEST_LIST))
report-newlib-nano: $(patsubst %,report-%-newlib-nano,$(REGRESSION_TEST_LIST))
.PHONY: report-gcc
report-gcc: report-gcc-newlib
.PHONY: report-dhrystone
report-dhrystone: report-dhrystone-newlib
.PHONY: report-binutils
report-binutils: report-binutils-newlib
.PHONY: report-gdb
report-gdb: report-gdb-newlib

.PHONY: build-sim
ifeq ($(SIM),qemu)
SIM_PATH:=$(srcdir)/scripts/wrapper/qemu:$(srcdir)/scripts
SIM_PREPARE:=PATH="$(SIM_PATH):$(INSTALL_DIR)/bin:$(PATH)" RISC_V_SYSROOT="$(SYSROOT)"
SIM_STAMP:= stamps/build-qemu
else
ifeq ($(SIM),spike)
# Using spike simulator.
SIM_PATH:=$(srcdir)/scripts/wrapper/spike:$(srcdir)/scripts
SIM_PREPARE:=PATH="$(SIM_PATH):$(INSTALL_DIR)/bin:$(PATH)" PK_PATH="$(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/" ARCH_STR="$(WITH_ARCH)"
SIM_STAMP:= stamps/build-spike
ifneq (,$(findstring rv32,$(NEWLIB_MULTILIB_NAMES)))
SIM_STAMP+= stamps/build-pk32
endif
ifneq (,$(findstring rv64,$(NEWLIB_MULTILIB_NAMES)))
SIM_STAMP+= stamps/build-pk64
endif
else
ifeq ($(SIM),gdb)
# Using gdb simulator.
SIM_PATH:=$(INSTALL_DIR)/bin
SIM_PREPARE:=
else
$(error "Only support SIM=spike, SIM=gdb or SIM=qemu (default).")
endif
endif
endif

build-sim: $(SIM_STAMP)

stamps/check-write-permission:
	mkdir -p $(INSTALL_DIR)/.test || \
		(echo "Sorry, you don't have permission to write to" \
		 "'$(INSTALL_DIR)'. Please make sure that the location is " \
		 "writable or use --prefix to specify another destination.'" \
		 && exit 1)
	rm -r $(INSTALL_DIR)/.test
	mkdir -p $(dir $@) && touch $@

stamps/build-linux-headers:
	mkdir -p $(SYSROOT)/usr/
ifdef LINUX_HEADERS_SRCDIR
	cp -a $(LINUX_HEADERS_SRCDIR) $(SYSROOT)/usr/
else
	cp -a $(srcdir)/linux-headers/include $(SYSROOT)/usr/
endif
	mkdir -p $(dir $@) && touch $@

#
# Rule for auto init submodules
#

ifeq ($(findstring $(srcdir),$(GCC_SRCDIR)),$(srcdir))
GCC_SRC_GIT := $(GCC_SRCDIR)/.git
else
GCC_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(BINUTILS_SRCDIR)),$(srcdir))
BINUTILS_SRC_GIT := $(BINUTILS_SRCDIR)/.git
else
BINUTILS_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(GDB_SRCDIR)),$(srcdir))
GDB_SRC_GIT := $(GDB_SRCDIR)/.git
else
GDB_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(NEWLIB_SRCDIR)),$(srcdir))
NEWLIB_SRC_GIT := $(NEWLIB_SRCDIR)/.git
else
NEWLIB_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(GLIBC_SRCDIR)),$(srcdir))
GLIBC_SRC_GIT := $(GLIBC_SRCDIR)/.git
else
GLIBC_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(MUSL_SRCDIR)),$(srcdir))
MUSL_SRC_GIT := $(MUSL_SRCDIR)/.git
else
MUSL_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(UCLIBC_SRCDIR)),$(srcdir))
UCLIBC_SRC_GIT := $(UCLIBC_SRCDIR)/.git
else
UCLIBC_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(QEMU_SRCDIR)),$(srcdir))
QEMU_SRC_GIT := $(QEMU_SRCDIR)/.git
else
QEMU_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(SPIKE_SRCDIR)),$(srcdir))
SPIKE_SRC_GIT := $(SPIKE_SRCDIR)/.git
PK_SRC_GIT := $(PK_SRCDIR)/.git
else
SPIKE_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(LLVM_SRCDIR)),$(srcdir))
LLVM_SRC_GIT := $(LLVM_SRCDIR)/.git
else
LLVM_SRC_GIT :=
endif

ifeq ($(findstring $(srcdir),$(DEJAGNU_SRCDIR)),$(srcdir))
DEJAGNU_SRC_GIT := $(DEJAGNU_SRCDIR)/.git
else
DEJAGNU_SRC_GIT :=
endif

ifneq ("$(wildcard $(GCC_SRCDIR)/.git)","")
GCCPKGVER := g$(shell git -C $(GCC_SRCDIR) describe --always --dirty --exclude '*')
else
GCCPKGVER :=
endif

$(srcdir)/%/.git:
	cd $(srcdir) && \
	flock `git rev-parse --git-dir`/config git submodule init $(dir $@) && \
	flock `git rev-parse --git-dir`/config git submodule update --progress --depth 1 $(dir $@)

stamps/install-host-gcc: $(GCC_SRCDIR) $(GCC_SRC_GIT)
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(builddir)/install-host-gcc \
		--with-system-zlib \
		--enable-languages=c,c++ \
		--disable-bootstrap \
		--disable-multilib
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

#
# GLIBC
#

stamps/build-binutils-linux: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(GLIBC_CC_FOR_TARGET) $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--enable-plugins \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gdb-linux: $(GDB_SRCDIR) $(GDB_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(GLIBC_CC_FOR_TARGET) $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(GDB_TARGET_FLAGS) \
		--enable-gdb \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-glibc-linux-headers: $(GLIBC_SRCDIR) $(GLIBC_SRC_GIT) stamps/build-gcc-linux-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && CC="$(GLIBC_CC_FOR_TARGET)" $</configure \
		--host=$(LINUX_TUPLE) \
		--prefix=$(SYSROOT)/usr \
		--enable-shared \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		--disable-multilib \
		--enable-kernel=3.0.0
	$(MAKE) -C $(notdir $@) install-headers
	mkdir -p $(dir $@) && touch $@

stamps/build-glibc-linux-%: $(GLIBC_SRCDIR) $(GLIBC_SRC_GIT) stamps/build-gcc-linux-stage1
ifeq ($(MULTILIB_FLAGS),--enable-multilib)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
else
	$(eval $@_ARCH := )
	$(eval $@_ABI := )
endif
	$(eval $@_LIBDIRSUFFIX := $(if $($@_ABI),$(shell echo $($@_ARCH) | sed 's/.*rv\([0-9]*\).*/\1/')/$($@_ABI),))
	$(eval $@_XLEN := $(if $($@_ABI),$(shell echo $($@_ARCH) | sed 's/.*rv\([0-9]*\).*/\1/'),$(XLEN)))
	$(eval $@_CFLAGS := $(if $($@_ABI),-march=$($@_ARCH) -mabi=$($@_ABI),))
	$(eval $@_LIBDIROPTS := $(if $@_LIBDIRSUFFIX,--libdir=/usr/lib$($@_LIBDIRSUFFIX) libc_cv_slibdir=/lib$($@_LIBDIRSUFFIX) libc_cv_rtlddir=/lib,))
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && \
		CC="$(GLIBC_CC_FOR_TARGET) $($@_CFLAGS)" \
		CXX="this-is-not-the-compiler-youre-looking-for" \
		CFLAGS="$(CFLAGS_FOR_TARGET) -O2 $($@_CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS_FOR_TARGET) -O2 $($@_CFLAGS)" \
		ASFLAGS="$(ASFLAGS_FOR_TARGET) $($@_CFLAGS)" \
		$</configure \
		--host=$(call make_tuple,$($@_XLEN),linux-gnu) \
		--prefix=/usr \
		--disable-werror \
		--enable-shared \
		--enable-obsolete-rpc \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		$(MULTILIB_FLAGS) \
		--enable-kernel=3.0.0 \
		$(GLIBC_TARGET_FLAGS) \
		$($@_LIBDIROPTS)
	$(MAKE) -C $(notdir $@)
	+flock $(SYSROOT)/.lock $(MAKE) -C $(notdir $@) install install_root=$(SYSROOT)
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-linux-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-linux \
                               stamps/build-linux-headers
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-newlib \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(ENABLE_DEFAULT_PIE) \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-target-libgcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-target-libgcc
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-linux-stage2: ENABLED_LANGUAGES?="c,c++,fortran"
stamps/build-gcc-linux-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) $(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES)) \
                               stamps/build-glibc-linux-headers
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-pkgversion="$(GCCPKGVER)" \
		--with-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=$(ENABLED_LANGUAGES) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		$(ENABLE_LIBSANITIZER) \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(ENABLE_DEFAULT_PIE) \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(LINUX_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

stamps/build-binutils-linux-native: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) stamps/build-gcc-linux-stage2 $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--host=$(LINUX_TUPLE) \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR)/native \
		--enable-plugins \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_NATIVE_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@


stamps/build-gcc-linux-native: ENABLED_LANGUAGES?="c,c++,fortran"
stamps/build-gcc-linux-native: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-gcc-linux-stage2 stamps/build-binutils-linux-native
	if test -f $</contrib/download_prerequisites; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--host=$(LINUX_TUPLE) \
		--target=$(LINUX_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR)/native \
		--without-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=$(ENABLED_LANGUAGES) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-nls \
		--disable-bootstrap \
                --with-native-system-header-dir=$(INSTALL_DIR)/native/include \
		$(GCC_CHECKING_FLAGS) \
		$(MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(LINUX_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

#
# NEWLIB
#

stamps/build-binutils-newlib: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(NEWLIB_CC_FOR_TARGET) $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--enable-plugins \
		 \
		--disable-werror \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gdb-newlib: $(GDB_SRCDIR) $(GDB_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(NEWLIB_CC_FOR_TARGET) $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		 \
		--disable-werror \
		$(GDB_TARGET_FLAGS) \
		--enable-gdb \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-newlib-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-newlib
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--disable-shared \
		--disable-threads \
		--disable-tls \
		--enable-languages=c,c++ \
		--with-system-zlib \
		--with-newlib \
		--with-sysroot=$(INSTALL_DIR)/$(NEWLIB_TUPLE) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(GCC_MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-Os $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) all-gcc
	$(MAKE) -C $(notdir $@) install-gcc
	mkdir -p $(dir $@) && touch $@

stamps/build-newlib: $(NEWLIB_SRCDIR) $(NEWLIB_SRC_GIT) stamps/build-gcc-newlib-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--enable-newlib-io-long-double \
		--enable-newlib-io-long-long \
		--enable-newlib-io-c99-formats \
		--enable-newlib-register-fini \
		CFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE -ffunction-sections -fdata-sections $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 -D_POSIX_MODE -ffunction-sections -fdata-sections $(CXXFLAGS_FOR_TARGET)" \
		$(NEWLIB_TARGET_FLAGS)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-newlib-nano: $(NEWLIB_SRCDIR) $(NEWLIB_SRC_GIT) stamps/build-gcc-newlib-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(builddir)/install-newlib-nano \
		--enable-newlib-reent-small \
		--disable-newlib-fvwrite-in-streamio \
		--disable-newlib-fseek-optimization \
		--disable-newlib-wide-orient \
		--enable-newlib-nano-malloc \
		--disable-newlib-unbuf-stream-opt \
		--enable-lite-exit \
		--enable-newlib-global-atexit \
		--enable-newlib-nano-formatted-io \
		--disable-newlib-supplied-syscalls \
		--disable-nls \
		CFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections $(CXXFLAGS_FOR_TARGET)" \
		$(NEWLIB_TARGET_FLAGS)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/merge-newlib-nano: stamps/build-newlib-nano stamps/build-newlib
# Copy nano library files into newlib install dir.
	if [ -f $(INSTALL_DIR)/bin/$(NEWLIB_TUPLE)-gcc ] ; then \
		export NEWLIB_CC_FOR_MULTILIB_INFO="$(INSTALL_DIR)/bin/$(NEWLIB_TUPLE)-gcc"; \
	else \
		export NEWLIB_CC_FOR_MULTILIB_INFO="$(NEWLIB_CC_FOR_TARGET)"; \
	fi
	set -e; \
        for ml in `${NEWLIB_CC_FOR_MULTILIB_INFO} --print-multi-lib`; \
	do \
	    mld=`echo $${ml} | sed -e 's/;.*$$//'`; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libc.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libc_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libm.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libm_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libg.a \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libg_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/libgloss.a\
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/libgloss_nano.a; \
	    cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/lib/$${mld}/crt0.o\
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/lib/$${mld}/crt0.o; \
	done
# Copy nano header files into newlib install dir.
	mkdir -p $(INSTALL_DIR)/$(NEWLIB_TUPLE)/include/newlib-nano; \
	cp $(builddir)/install-newlib-nano/$(NEWLIB_TUPLE)/include/newlib.h \
		$(INSTALL_DIR)/$(NEWLIB_TUPLE)/include/newlib-nano/newlib.h; \
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-newlib-stage2: ENABLED_LANGUAGES?="c,c++"
stamps/build-gcc-newlib-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-newlib \
		stamps/merge-newlib-nano
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(NEWLIB_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--disable-shared \
		--disable-threads \
		--enable-languages=$(ENABLED_LANGUAGES) \
		--with-pkgversion="$(GCCPKGVER)" \
		--with-system-zlib \
		--enable-tls \
		--with-newlib \
		--with-sysroot=$(INSTALL_DIR)/$(NEWLIB_TUPLE) \
		--with-native-system-header-dir=/include \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-tm-clone-registry \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		$(GCC_MULTILIB_FLAGS) \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-Os $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-Os $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

#
# MUSL
#

stamps/build-binutils-musl: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(MUSL_CC_FOR_TARGET) $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--enable-plugins \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gdb-musl: $(GDB_SRCDIR) $(GDB_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(MUSL_CC_FOR_TARGET) $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(GDB_TARGET_FLAGS) \
		--enable-gdb \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-musl-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-musl \
                               stamps/build-linux-headers
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(ENABLE_DEFAULT_PIE) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-target-libgcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-target-libgcc
	mkdir -p $(dir $@) && touch $@

stamps/build-musl-linux-headers: $(MUSL_SRCDIR) $(MUSL_SRC_GIT) stamps/build-gcc-musl-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && CC="$(MUSL_CC_FOR_TARGET)" $</configure \
		--host=$(MUSL_TUPLE) \
		--prefix=$(SYSROOT)/usr \
		--enable-shared \
		--with-headers=$(LINUX_HEADERS_SRCDIR) \
		--disable-multilib \
		--enable-kernel=3.0.0
	$(MAKE) -C $(notdir $@) install-headers
	mkdir -p $(dir $@) && touch $@

stamps/build-musl-linux: $(MUSL_SRCDIR) $(MUSL_SRC_GIT) stamps/build-gcc-musl-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && \
		CC="$(MUSL_CC_FOR_TARGET) $($@_CFLAGS)" \
		CXX="$(MUSL_CXX_FOR_TARGET) $($@_CFLAGS)" \
		CFLAGS="$(CFLAGS_FOR_TARGET) -O2 $($@_CFLAGS)" \
		CXXFLAGS="$(CXXFLAGS_FOR_TARGET) -O2 $($@_CFLAGS)" \
		ASFLAGS="$(ASFLAGS_FOR_TARGET) $($@_CFLAGS)" \
		$</configure \
		--host=$(MUSL_TUPLE) \
		--prefix=$(SYSROOT) \
		--disable-werror \
		--enable-shared \
		$(MUSL_TARGET_FLAGS)
	$(MAKE) -C $(notdir $@)
	+flock $(SYSROOT)/.lock $(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-musl-stage2: ENABLED_LANGUAGES?="c,c++"
stamps/build-gcc-musl-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-musl-linux \
                               stamps/build-musl-linux-headers
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	# Disable libsanitizer for now
	# https://github.com/google/sanitizers/issues/1080
	cd $(notdir $@) && $</configure \
		--target=$(MUSL_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-system-zlib \
		--enable-shared \
		--enable-tls \
		--enable-languages=$(ENABLED_LANGUAGES) \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(ENABLE_DEFAULT_PIE) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(MUSL_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@

#
# UCLIBC
#

stamps/build-binutils-uclibc: $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
# CC_FOR_TARGET is required for the ld testsuite.
	cd $(notdir $@) && CC_FOR_TARGET=$(UCLIBC_CC_FOR_TARGET) $</configure \
		--target=$(UCLIBC_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--enable-plugins \
		$(MULTILIB_FLAGS) \
		 \
		--disable-werror \
		--disable-nls \
		$(BINUTILS_TARGET_FLAGS) \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline \
		$(WITH_ISA_SPEC)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-uclibc-stage1: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-binutils-uclibc \
                               stamps/build-linux-headers
	if test -f $</contrib/download_prerequisites && test "false" = "true"; then cd $< && ./contrib/download_prerequisites; fi
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(UCLIBC_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--without-headers \
		--disable-shared \
		--disable-threads \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=c \
		--disable-libatomic \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libgomp \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-gcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true all-target-libgcc
	$(MAKE) -C $(notdir $@) inhibit-libc=true install-target-libgcc
	mkdir -p $(dir $@) && touch $@

stamps/build-uclibc-linux: $(UCLIBC_SRCDIR) $(UCLIBC_SRC_GIT) stamps/build-gcc-uclibc-stage1
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)

	echo "# ARCH_USE_MMU is not set" > $(notdir $@)/.config && \
	echo "UCLIBC_HAS_LINUXTHREADS=y" >> $(notdir $@)/.config && \
	echo "DO_C99_MATH=y" >> $(notdir $@)/.config && \
	echo "UCLIBC_HAS_UTMPX=y" >> $(notdir $@)/.config && \
	echo "UCLIBC_SUSV3_LEGACY=y" >> $(notdir $@)/.config && \
	echo "UCLIBC_SUSV3_LEGACY_MACROS=y" >> $(notdir $@)/.config && \
	echo "UCLIBC_SUSV4_LEGACY=y" >> $(notdir $@)/.config && \
	echo "UCLIBC_HAS_RESOLVER_SUPPORT=y" >> $(notdir $@)/.config && \
	echo "KERNEL_HEADERS=\"$(LINUX_HEADERS_SRCDIR)\"" >> $(notdir $@)/.config && \
	echo "RUNTIME_PREFIX=\"/\"" >> $(notdir $@)/.config && \
	echo "DEVEL_PREFIX=\"/usr\"" >> $(notdir $@)/.config && \
	O="$$(realpath $(notdir $@))" \
	ARCH=riscv$(XLEN) \
	CROSS_COMPILE=$(UCLIBC_TUPLE)- \
	$(MAKE) -C $< olddefconfig

	O="$$(realpath $(notdir $@))" \
	ARCH=riscv$(XLEN) \
	PREFIX=$(SYSROOT) \
	CROSS_COMPILE=$(UCLIBC_TUPLE)- \
	UCLIBC_EXTRA_CFLAGS="$(CFLAGS_FOR_TARGET)" \
	UCLIBC_EXTRA_CPPFLAGS="$(CXXFLAGS_FOR_TARGET)" \
	$(MAKE) -C $< install
	cp -a $(notdir $@)/lib/*\.so $(SYSROOT)/usr/lib/
	cp -a $(notdir $@)/lib/*\.so.* $(SYSROOT)/usr/lib/
	ln -f $(SYSROOT)/usr/lib/crt1.o $(SYSROOT)/usr/lib/Scrt1.o

	mkdir -p $(dir $@) && touch $@

stamps/build-gcc-uclibc-stage2: ENABLED_LANGUAGES?="c,c++"
stamps/build-gcc-uclibc-stage2: $(GCC_SRCDIR) $(GCC_SRC_GIT) stamps/build-uclibc-linux
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--target=$(UCLIBC_TUPLE) \
		$(CONFIGURE_HOST) \
		--prefix=$(INSTALL_DIR) \
		--with-sysroot=$(SYSROOT) \
		--with-system-zlib \
		--enable-tls \
		--enable-languages=$(ENABLED_LANGUAGES) \
		--disable-shared \
		--disable-libmudflap \
		--disable-libssp \
		--disable-libquadmath \
		--disable-libsanitizer \
		--disable-nls \
		--disable-bootstrap \
		--src=$(gccsrcdir) \
		$(GCC_CHECKING_FLAGS) \
		--disable-multilib \
		$(WITH_ABI) \
		$(WITH_ARCH) \
		$(WITH_TUNE) \
		$(WITH_ISA_SPEC) \
		$(GCC_EXTRA_CONFIGURE_FLAGS) \
		CFLAGS_FOR_TARGET="-O2 $(CFLAGS_FOR_TARGET)" \
		CXXFLAGS_FOR_TARGET="-O2 $(CXXFLAGS_FOR_TARGET)"
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp -a $(INSTALL_DIR)/$(UCLIBC_TUPLE)/lib* $(SYSROOT)
	mkdir -p $(dir $@) && touch $@


stamps/build-spike: $(SPIKE_SRCDIR) $(SPIKE_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/build-pk32: $(PK_SRCDIR) $(PK_SRC_GIT) stamps/build-gcc-newlib-stage2
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--host=$(NEWLIB_TUPLE) \
		--with-arch=rv32gc \
		--with-abi=ilp32f
	$(MAKE) -C $(notdir $@)
	cp $(notdir $@)/pk $(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/pk32
	mkdir -p $(dir $@)
	date > $@

stamps/build-pk64: $(PK_SRCDIR) $(PK_SRC_GIT) stamps/build-gcc-newlib-stage2
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--host=$(NEWLIB_TUPLE) \
		--with-arch=rv64gc \
		--with-abi=lp64d
	$(MAKE) -C $(notdir $@)
	cp $(notdir $@)/pk $(INSTALL_DIR)/$(NEWLIB_TUPLE)/bin/pk64
	mkdir -p $(dir $@)
	date > $@

stamps/build-qemu: $(QEMU_SRCDIR) $(QEMU_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR) \
		--target-list=$(QEMU_TARGETS) \
		--interp-prefix=$(INSTALL_DIR)/sysroot \
		--python=python3
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/build-llvm-linux: $(LLVM_SRCDIR) $(LLVM_SRC_GIT) $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) \
                         stamps/build-gcc-linux-stage2
	# We have the following situation:
	# - sysroot directory: $(INSTALL_DIR)/sysroot
	# - GCC install directory: $(INSTALL_DIR)
	# However, LLVM does not allow to set a GCC install prefix
	# (-DGCC_INSTALL_PREFIX) if a sysroot (-DDEFAULT_SYSROOT) is set
	# (the GCC install prefix will be ignored silently).
	# Without a proper sysroot path feature.h won't be found by clang.
	# Without a proper GCC install directory libgcc won't be found.
	# As a workaround we have to merge both paths:
	mkdir -p $(SYSROOT)/lib/
	ln -s -f $(INSTALL_DIR)/lib/gcc $(SYSROOT)/lib/gcc
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && ln -f -s $(SYSROOT) sysroot
	cd $(notdir $@) && \
	    cmake $(LLVM_SRCDIR)/llvm \
	    -DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR) \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DLLVM_TARGETS_TO_BUILD="RISCV" \
	    -DLLVM_ENABLE_PROJECTS="clang;lld" \
	    -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind" \
	    -DLLVM_DEFAULT_TARGET_TRIPLE="$(LINUX_TUPLE)" \
	    -DDEFAULT_SYSROOT="../sysroot" \
	    -DLLVM_RUNTIME_TARGETS=$(call make_tuple,$(XLEN),linux-gnu) \
	    -DLLVM_INSTALL_TOOLCHAIN_ONLY=On \
	    -DLLVM_BINUTILS_INCDIR=$(BINUTILS_SRCDIR)/include \
	    -DLLVM_PARALLEL_LINK_JOBS=4
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	# Build shared/static OpenMP libraries on RV64.
	if test $(XLEN) -eq 64; then \
	    mkdir $(notdir $@)/openmp-shared; \
	    cmake -S$(LLVM_SRCDIR)/openmp \
	        -B$(notdir $@)/openmp-shared \
	        -DCMAKE_INSTALL_PREFIX=$(SYSROOT) \
	        -DCMAKE_C_COMPILER=$(INSTALL_DIR)/bin/clang \
	        -DCMAKE_CXX_COMPILER=$(INSTALL_DIR)/bin/clang++ \
	        -DOPENMP_ENABLE_LIBOMPTARGET=Off \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DLIBOMP_ARCH=riscv64 \
	        -DLIBOMP_HAVE_WARN_SHARED_TEXTREL_FLAG=On \
	        -DLIBOMP_HAVE_AS_NEEDED_FLAG=On \
	        -DLIBOMP_HAVE_VERSION_SCRIPT_FLAG=On \
	        -DLIBOMP_HAVE_STATIC_LIBGCC_FLAG=On \
	        -DLIBOMP_HAVE_Z_NOEXECSTACK_FLAG=On \
	        -DDISABLE_OMPD_GDB_PLUGIN=On \
	        -DLIBOMP_OMPD_GDB_SUPPORT=Off \
	        -DLIBOMP_ENABLE_SHARED=On; \
	    $(MAKE) -C $(notdir $@)/openmp-shared; \
	    $(MAKE) -C $(notdir $@)/openmp-shared install; \
	    mkdir $(notdir $@)/openmp-static; \
	    cmake -S$(LLVM_SRCDIR)/openmp \
	        -B$(notdir $@)/openmp-static \
	        -DCMAKE_INSTALL_PREFIX=$(SYSROOT) \
	        -DCMAKE_C_COMPILER=$(INSTALL_DIR)/bin/clang \
	        -DCMAKE_CXX_COMPILER=$(INSTALL_DIR)/bin/clang++ \
	        -DOPENMP_ENABLE_LIBOMPTARGET=Off \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DLIBOMP_ARCH=riscv64 \
	        -DLIBOMP_HAVE_WARN_SHARED_TEXTREL_FLAG=On \
	        -DLIBOMP_HAVE_AS_NEEDED_FLAG=On \
	        -DLIBOMP_HAVE_VERSION_SCRIPT_FLAG=On \
	        -DLIBOMP_HAVE_STATIC_LIBGCC_FLAG=On \
	        -DLIBOMP_HAVE_Z_NOEXECSTACK_FLAG=On \
	        -DDISABLE_OMPD_GDB_PLUGIN=On \
	        -DLIBOMP_OMPD_GDB_SUPPORT=Off \
	        -DLIBOMP_ENABLE_SHARED=Off; \
	    $(MAKE) -C $(notdir $@)/openmp-static; \
	    $(MAKE) -C $(notdir $@)/openmp-static install; \
	fi
	cp $(notdir $@)/lib/riscv$(XLEN)-unknown-linux-gnu/libc++* $(SYSROOT)/lib
	cp $(notdir $@)/lib/LLVMgold.$(SHARED_LIB_SUFFIX) $(INSTALL_DIR)/lib
	cd $(INSTALL_DIR)/bin && ln -s -f clang $(LINUX_TUPLE)-clang && ln -s -f clang++ $(LINUX_TUPLE)-clang++
	mkdir -p $(dir $@) && touch $@

stamps/build-llvm-newlib: $(LLVM_SRCDIR) $(LLVM_SRC_GIT) $(BINUTILS_SRCDIR) $(BINUTILS_SRC_GIT) \
                          stamps/build-gcc-newlib-stage2
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && \
	    cmake $(LLVM_SRCDIR)/llvm \
	    -DCMAKE_INSTALL_PREFIX=$(INSTALL_DIR) \
	    -DCMAKE_BUILD_TYPE=Release \
	    -DLLVM_TARGETS_TO_BUILD="RISCV" \
	    -DLLVM_ENABLE_PROJECTS="clang;lld" \
	    -DLLVM_DEFAULT_TARGET_TRIPLE="$(NEWLIB_TUPLE)" \
	    -DLLVM_INSTALL_TOOLCHAIN_ONLY=On \
	    -DLLVM_BINUTILS_INCDIR=$(BINUTILS_SRCDIR)/include \
	    -DLLVM_PARALLEL_LINK_JOBS=4
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	cp $(notdir $@)/lib/LLVMgold.$(SHARED_LIB_SUFFIX) $(INSTALL_DIR)/lib
	cd $(INSTALL_DIR)/bin && ln -s -f clang $(NEWLIB_TUPLE)-clang && \
	    ln -s -f clang++ $(NEWLIB_TUPLE)-clang++
	mkdir -p $(dir $@) && touch $@

stamps/build-dejagnu: $(DEJAGNU_SRCDIR) $(DEJAGNU_SRC_GIT) $(PREPARATION_STAMP)
	rm -rf $@ $(notdir $@)
	mkdir $(notdir $@)
	cd $(notdir $@) && $</configure \
		--prefix=$(INSTALL_DIR)
	$(MAKE) -C $(notdir $@)
	$(MAKE) -C $(notdir $@) install
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-newlib: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-newlib-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(NEWLIB_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-newlib-nano: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-newlib-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(NEWLIB_NANO_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-gcc-linux: stamps/build-gcc-linux-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gcc-linux-stage2 check-gcc "RUNTESTFLAGS=$(RUNTESTFLAGS) --target_board='$(GLIBC_TARGET_BOARDS)'"
	mkdir -p $(dir $@)
	date > $@

stamps/check-glibc-linux-%: stamps/build-gcc-linux-stage2 $(SIM_STAMP) stamps/build-dejagnu \
		$(addprefix stamps/build-glibc-linux-,$(GLIBC_MULTILIB_NAMES))
	$(eval $@_BUILD_DIR := $(notdir $@))
	$(eval $@_BUILD_DIR := $(subst check-,build-,$($@_BUILD_DIR)))
	$(SIM_PREPARE) $(MAKE) -C $($@_BUILD_DIR) check
	mkdir -p $(dir $@)
	date > $@

.PHONY: check-dhrystone-newlib check-dhrystone-newlib-nano
check-dhrystone-newlib: $(patsubst %,stamps/check-dhrystone-newlib-%,$(NEWLIB_MULTILIB_NAMES))
check-dhrystone-newlib-nano: $(patsubst %,stamps/check-dhrystone-newlib-nano-%,$(NEWLIB_MULTILIB_NAMES))

stamps/check-dhrystone-newlib-%: \
		stamps/build-gcc-newlib-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

stamps/check-dhrystone-newlib-nano-%: \
		stamps/build-gcc-newlib-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 5,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 6,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -specs=nano.specs -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

.PHONY: check-dhrystone-linux
check-dhrystone-linux: $(patsubst %,stamps/check-dhrystone-linux-%,$(GLIBC_MULTILIB_NAMES))

stamps/check-dhrystone-linux-%: \
		stamps/build-gcc-linux-stage2 \
		$(SIM_STAMP) \
		$(wildcard $(srcdir)/test/benchmarks/dhrystone/*)
	$(eval $@_ARCH := $(word 4,$(subst -, ,$@)))
	$(eval $@_ABI := $(word 5,$(subst -, ,$@)))
	$(eval $@_XLEN := $(patsubst rv32%,32,$(patsubst rv64%,64,$($@_ARCH))))
	$(SIM_PREPARE) $(srcdir)/test/benchmarks/dhrystone/check -march=$($@_ARCH) -mabi=$($@_ABI) -cc=riscv$(XLEN)-unknown-elf-gcc -objdump=riscv$(XLEN)-unknown-elf-objdump -sim=riscv$($@_XLEN)-unknown-elf-run -out=$@ $(filter %.c,$^) || true

stamps/check-binutils-newlib: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-newlib check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(NEWLIB_TARGET_BOARDS)'" || true
	date > $@

stamps/check-binutils-newlib-nano: stamps/build-gcc-newlib-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-newlib check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(NEWLIB_NANO_TARGET_BOARDS)'" || true
	date > $@

stamps/check-binutils-linux: stamps/build-gcc-linux-stage2 $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-binutils-linux check-binutils check-gas check-ld -k "RUNTESTFLAGS=--target_board='$(GLIBC_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-newlib: stamps/build-gcc-newlib-stage2 stamps/build-gdb-newlib $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-newlib check-gdb -k "RUNTESTFLAGS=--target_board='$(NEWLIB_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-newlib-nano: stamps/build-gcc-newlib-stage2 stamps/build-gdb-newlib $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-newlib check-gdb -k "RUNTESTFLAGS=--target_board='$(NEWLIB_NANO_TARGET_BOARDS)'" || true
	date > $@

stamps/check-gdb-linux: stamps/build-gcc-linux-stage2 stamps/build-gdb-linux $(SIM_STAMP) stamps/build-dejagnu
	$(SIM_PREPARE) $(MAKE) -C build-gdb-linux check-gdb -k "RUNTESTFLAGS=--target_board='$(GLIBC_TARGET_BOARDS)'" || true
	date > $@

.PHONY: report-gcc-newlib report-gcc-newlib-nano
report-gcc-newlib: stamps/check-gcc-newlib
	$(srcdir)/scripts/testsuite-filter gcc newlib $(srcdir)/test/allowlist `find build-gcc-newlib-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

report-gcc-newlib-nano: stamps/check-gcc-newlib-nano
	$(srcdir)/scripts/testsuite-filter gcc newlib-nano $(srcdir)/test/allowlist `find build-gcc-newlib-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

.PHONY: report-gcc-linux
report-gcc-linux: stamps/check-gcc-linux
	$(srcdir)/scripts/testsuite-filter gcc glibc $(srcdir)/test/allowlist `find build-gcc-linux-stage2/gcc/testsuite/ -name *.sum |paste -sd "," -`

.PHONY: report-dhrystone-newlib report-dhrystone-newlib-nano
report-dhrystone-newlib: $(patsubst %,stamps/check-dhrystone-newlib-%,$(NEWLIB_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi
report-dhrystone-newlib-nano: $(patsubst %,stamps/check-dhrystone-newlib-nano-%,$(NEWLIB_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi

.PHONY: report-dhrystone-linux
report-dhrystone-linux: $(patsubst %,stamps/check-dhrystone-linux-%,$(GLIBC_MULTILIB_NAMES))
	if cat $^ | grep -v '^PASS'; then false; else true; fi

.PHONY: report-binutils-newlib report-binutils-newlib-nano
report-binutils-newlib: stamps/check-binutils-newlib
	$(srcdir)/scripts/testsuite-filter binutils newlib \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-newlib/ -name *.sum |paste -sd "," -`

report-binutils-newlib-nano: stamps/check-binutils-newlib-nano
	$(srcdir)/scripts/testsuite-filter binutils newlib-nano \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-newlib/ -name *.sum |paste -sd "," -`

.PHONY: report-binutils-linux
report-binutils-linux: stamps/check-binutils-linux
	$(srcdir)/scripts/testsuite-filter binutils glibc \
	    $(srcdir)/test/allowlist \
	    `find build-binutils-linux/ -name *.sum |paste -sd "," -`

clean:
	rm -rf build-* install-* stamps install-newlib-nano

.PHONY: report-gdb-newlib report-gdb-newlib-nano
report-gdb-newlib: stamps/check-gdb-newlib
	stat $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-newlib -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then false; else true; fi

report-gdb-newlib-nano: stamps/check-gdb-newlib-nano
	stat $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-newlib -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-newlib/%.log,$(NEWLIB_MULTILIB_NAMES)); then false; else true; fi

.PHONY: report-gdb-linux
report-gdb-linux: stamps/check-gdb-linux
	stat $(patsubst %,$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)) || exit 1
# Fail if there are blank lines in the log file used as input for grep below.
	if grep '^$$' $(patsubst %,$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)); then exit 1; fi
	if find build-gdb-linux -iname '*.sum' | xargs grep ^FAIL | sort | grep -F -v $(patsubst %,--file=$(srcdir)/test/gdb-linux/%.log,$(GLIBC_MULTILIB_NAMES)); then false; else true; fi

distclean: clean
	rm -rf src

# All of the packages install themselves, so our install target does nothing.
install:

# Rebuilding Makefile.
Makefile: $(srcdir)/Makefile.in config.status
	CONFIG_FILES=$@ CONFIG_HEADERS= $(SHELL) ./config.status

config.status: $(srcdir)/configure
	CONFIG_SHELL="$(SHELL)" $(SHELL) ./config.status --recheck
