![](https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/RISC-V-logo.svg/2560px-RISC-V-logo.svg.png)
# RISC-V GNU Compiler toolchain
This is the RISC-V C and C++ cross-compiler. It supports two build modes: a generic ELF/Newlib toolchain and a more sophisticated Linux-ELF/glibc toolchain.\
It's fork of [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) with improved building process when git submodules haven't found automaticly.\
**Warning: full clone for build takes around 6.65 GB of disk and download size.**
## Getting the sources
Cloning the repo using git.
```
git clone https://github.com/riscv/riscv-gnu-toolchain
```
## Requirements
Several standard packages are needed to build the toolchain.\
On Ubuntu, executing the following command should suffice:
```
sudo apt-get install autoconf automake autotools-dev curl python3 python3-pip python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libslirp-dev
```
On Fedora/CentOS/RHEL OS, executing the following command should suffice:
```
sudo dnf install autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel libslirp-devel
```
On Arch Linux, executing the following command should suffice:
```
sudo pacman -Syu curl python3 libmpc mpfr gmp base-devel texinfo gperf patchutils bc zlib expat libslirp
```
## Installation (Newlib)
Create directory in `/opt`:
```
mkdir riscv
cd riscv
mkdir bin
```
To build the Newlib cross-compiler, pick an install path (that is writeable). If you choose, say, `/opt/riscv`, then add `/opt/riscv/bin` to your `PATH`. 
```
export PATH="/opt/riscv:/opt/riscv/bin:$PATH"
```
Then, simply run the following command from directory with sources:
```
./configure --prefix=/opt/riscv
sudo make -j<COUNT-OF-CPU-CORES>
```
Replace `<COUNT-OF-CPU-CORES>` on count of CPU cores in your PC, for example: `sudo make -j8`.
## List of output binaries
* riscv64-unknown-elf-addr2line
* riscv64-unknown-elf-ar
* riscv64-unknown-elf-as
* riscv64-unknown-elf-c++
* riscv64-unknown-elf-c++filt
* riscv64-unknown-elf-cpp
* riscv64-unknown-elf-elfedit
* riscv64-unknown-elf-g++
* riscv64-unknown-elf-gcc
* riscv64-unknown-elf-gcc-ar
* riscv64-unknown-elf-gcc-nm
* riscv64-unknown-elf-gcc-ranlib
* riscv64-unknown-elf-gcov
* riscv64-unknown-elf-gcov-dump
* riscv64-unknown-elf-gcov-tool
* riscv64-unknown-elf-gdb
* riscv64-unknown-elf-gdb-add-index
* riscv64-unknown-elf-gprof
* riscv64-unknown-elf-gstack
* riscv64-unknown-elf-ld
* riscv64-unknown-elf-ld.bfd
* riscv64-unknown-elf-lto-dump
* riscv64-unknown-elf-nm
* riscv64-unknown-elf-objcopy
* riscv64-unknown-elf-objdump
* riscv64-unknown-elf-ranlib
* riscv64-unknown-elf-readelf
* riscv64-unknown-elf-run
* riscv64-unknown-elf-size
* riscv64-unknown-elf-strings
* riscv64-unknown-elf-strip
