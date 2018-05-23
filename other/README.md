# Xmrig (no donation allowed)

### Download release:

https://github.com/ddeeproton/xmrig-nvidia-manager/raw/master/other/xmrig-no_donation_allowed.exe

### Download source:

https://github.com/ddeeproton/xmrig-nvidia-manager/raw/master/other/SOURCE%20xmrig-master.zip

![](preview.png)

### How to buid (Windows)

#### 1. Download and install MSYS2 (MinGW):
http://www.msys2.org/

####2. Download and uncompress:
2.a. https://github.com/xmrig/xmrig/archive/master.zip

2.b. https://github.com/xmrig/xmrig-deps/releases

####3. Open MSYS2 (MinGW) terminal:

#### Win 64 bit:
pacman -Sy

pacman -S mingw-w64-x86_64-gcc

pacman -S make

pacman -S mingw-w64-x86_64-cmake

pacman -S mingw-w64-x86_64-pkg-config

#### Win 32 bit:
pacman -Sy

pacman -S mingw-w64-i686-gcc

pacman -S make

pacman -S mingw-w64-i686-cmake

pacman -S mingw-w64-i686-pkg-config

#### Go to directory unzipped in step 2.a.
cd "xmrig-master"

mkdir build

cd build

#### replace the path "c:/xmrig-deps/gcc/x64" by the path of directory unzopped in step 2.b.
cmake .. -G "Unix Makefiles" -DXMRIG_DEPS=c:/xmrig-deps/gcc/x64

make

