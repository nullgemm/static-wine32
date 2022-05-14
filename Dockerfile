FROM ubuntu:20.04

SHELL ["/bin/bash", "-c"]

RUN dpkg --add-architecture i386 && \
    apt update && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y build-essential pkg-config \
        gcc-multilib g++-multilib gcc-mingw-w64 libcrypt1-dev:i386 flex bison \
        python3 python3-pip wget git cmake ninja-build gperf automake \
        libtool autopoint gettext && \
    pip3 install mako jinja2 && \
    git clone --depth 1 https://github.com/mesonbuild/meson.git "$HOME/meson" && \
    echo "#!/bin/sh" > /usr/bin/meson && \
    echo "python3 \"$HOME/meson/meson.py\" \$@" > /usr/bin/meson && \
    chmod +x /usr/bin/meson && meson --version && \
    DEBIAN_FRONTEND=noninteractive apt install -y nano xvfb x11-apps \
        imagemagick && \
    echo "#!/bin/sh" > /usr/bin/startx && \
    echo "Xvfb \"\$DISPLAY\" -screen 0 1200x800x24 &" >> /usr/bin/startx && \
    echo >> /usr/bin/startx && \
    chmod +x /usr/bin/startx

ENV DISPLAY=:1

COPY dependencies /build
COPY meson-cross-i386 /build/

ARG WITH_GALLIUM

ARG PATH="$PATH:/usr/local/bin"

ARG CONFIGURE_FLAGS="CFLAGS=\"-m32 -O2\" CPPFLAGS=\"-m32 -O2\" CXXFLAGS=\"-m32 -O2\" OBJCFLAGS=\"-m32 -O2\" LDFLAGS=-m32"
ARG CONFIGURE_PROLOGUE="--prefix=/usr/local --sysconfdir=/etc"
ARG CONFIGURE_HOST="--host=i386-linux-gnu"
ARG MESON_PROLOGUE="--prefix=/usr/local --sysconfdir=/etc --buildtype=release --cross-file=../meson-cross-i386 --default-library=static --prefer-static"
ARG CMAKE_PROLOGUE="-DCMAKE_INSTALL_PREFIX=/usr/local -DSYSCONFDIR=/etc -DCMAKE_BUILD_TYPE=Release"

ARG DEP_BUILD_SCRIPTS="\
[macros-util-macros] autoreconf -v --install\n\
[macros-util-macros] ./configure $CONFIGURE_PROLOGUE $CONFIGURE_FLAGS\n\
[macros-util-macros] make install\n\
[zlib] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --static\n\
[zlib] make install\n\
[zstd] mkdir build/cmake/builddir\n\
[zstd] cd build/cmake/builddir\n\
[zstd] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DZSTD_BUILD_STATIC=ON -DZSTD_BUILD_SHARED=OFF -DZSTD_BUILD_PROGRAMS=OFF -DZSTD_BUILD_TESTS=OFF ..\n\
[zstd] make install\n\
[libjpeg-turbo] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DENABLE_STATIC=TRUE -DENABLE_SHARED=FALSE -DWITH_TURBOJPEG=FALSE\n\
[libjpeg-turbo] make install\n\
[libxkbcommon] meson setup build $MESON_PROLOGUE \
-Denable-wayland=false \
-Denable-docs=false \n\
[libxkbcommon] cd build\n\
[libxkbcommon] meson compile xkbcommon xkbcommon-x11\n\
[libxkbcommon] meson install --no-rebuild\n\
[fontconfig] ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared --disable-docs $CONFIGURE_FLAGS\n\
[fontconfig] make install\n\
[SDL] mkdir build\n\
[SDL] cd build\n\
[SDL] $CONFIGURE_FLAGS CFLAGS=\"\$CFLAGS -DSDL_VIDEO_DRIVER_X11_SUPPORTS_GENERIC_EVENTS=1\" cmake $CMAKE_PROLOGUE \
-DLIBTYPE=STATIC -DBUILD_SHARED_LIBS=OFF ..\n\
[SDL] make install\n\
[Linux-PAM] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --includedir=/usr/local/include/security --enable-static --disable-shared\n\
[Linux-PAM] make install\n\
[libcap] sed -i 's/.*\$(MAKE) -C tests \$@.*//' Makefile\n\
[libcap] sed -i 's/.*\$(MAKE) -C progs \$@.*//' Makefile\n\
[libcap] sed -i 's/.*\$(MAKE) -C doc \\\$@.*//' Makefile\n\
[libcap] COPTS=\"-m32 -O2\" lib=lib prefix=/usr/local SHARED=no make install\n\
[libcap-ng] ./autogen.sh\n\
[libcap-ng] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared --without-python3\n\
[libcap-ng] make install\n\
[util-linux] ./autogen.sh\n\
[util-linux] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --enable-static --disable-shared \
--without-python --disable-fdisks --disable-mount --disable-losetup --disable-zramctl \
--disable-fsck --disable-partx --disable-uuidd --disable-uuidgen --disable-blkid \
--disable-wipefs --disable-mountpoint --disable-fallocate --disable-unshare \
--disable-nsenter --disable-setpriv --disable-hardlink --disable-eject --disable-agetty \
--disable-cramfs --disable-bfs --disable-minix --disable-hwclock --disable-mkfs \
--disable-fstrim --disable-swapon --disable-lscpu --disable-lsfd --disable-lslogins \
--disable-wdctl --disable-cal --disable-logger --disable-whereis --disable-switch_root \
--disable-pivot_root --disable-lsmem --disable-chmem --disable-ipcmk --disable-ipcrm \
--disable-ipcs --disable-irqtop --disable-lsirq --disable-rfkill --disable-scriptutils \
--disable-kill --disable-last --disable-utmpdump --disable-mesg --disable-raw \
--disable-rename --disable-chfn-chsh --disable-login --disable-nologin --disable-sulogin \
--disable-su --disable-runuser --disable-ul --disable-more --disable-setterm \
--disable-schedutils --disable-wall --disable-bash-completion\n\
[util-linux] make install\n\
[systemd] sed -i 's/\\(input : .libudev.pc.in.,\\)/\\1 install_tag: '\"'\"'devel'\"'\"',/' src/libudev/meson.build\n\
[systemd] meson setup build $MESON_PROLOGUE -Drootlibdir=/usr/local/lib -Dstatic-libudev=true\n\
[systemd] cd build\n\
[systemd] meson compile basic:static_library udev:static_library libudev.pc\n\
[systemd] meson install --tags devel --no-rebuild\n\
[systemd] rm /usr/local/lib/*.so\n\
[libdrm] meson setup build $MESON_PROLOGUE\n\
[libdrm] meson install -C build\n\
[tdb] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-python\n\
[tdb] make install\n\
[tdb] rm /usr/local/lib/libtdb.so*\n\
-Dshared-glapi=false\n\
[glib] meson setup build $MESON_PROLOGUE -Dtests=false\n\
[glib] ninja -C build install\n\
[pulseaudio] sed -i 's/\\(input : .PulseAudioConfigVersion.cmake.in.,\\)/\\1 install_tag : '\"'\"'devel'\"'\"',/' meson.build\n\
[pulseaudio] find . -name meson.build -exec sed -i 's/=[[:space:]]*shared_library(/= library(/g' {} \\;\n\
[pulseaudio] meson setup build $MESON_PROLOGUE -Ddaemon=false -Ddoxygen=false \
-Dgcov=false -Dman=false -Dtests=false\n\
[pulseaudio] cd build\n\
[pulseaudio] meson compile pulse-simple \
pulsecommon-`echo "\$PWD" | sed 's/.*pulseaudio-\\([0-9]\\{1,\}\\.[0-9]\\{1,\\}\\).*/\\1/'` \
pulse-mainloop-glib pulse pulsedsp\n\
[pulseaudio] meson install --tags devel --no-rebuild\n\
[openal-soft] cd build\n\
[openal-soft] $CONFIGURE_FLAGS cmake $CMAKE_PROLOGUE -DLIBTYPE=STATIC \
-DALSOFT_BACKEND_OSS=OFF \
-DALSOFT_UTILS=OFF \
-DALSOFT_NO_CONFIG_UTIL=ON \
-DALSOFT_EXAMPLES=OFF \
-DALSOFT_INSTALL_CONFIG=OFF \
-DALSOFT_INSTALL_HRTF_DATA=OFF \
-DALSOFT_INSTALL_AMBDEC_PRESETS=OFF ..\n\
[openal-soft] make install\n\
[libunwind] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE $CONFIGURE_HOST --enable-static --disable-shared\n\
[libunwind] make install\n\
[llvmorg] `[ -z \"$WITH_GALLIUM\" ] && echo return`\n\
[llvmorg] cmake $CMAKE_PROLOGUE -S llvm -B build \
[llvmorg] -DLLVM_TARGETS_TO_BUILD=X86 \
[llvmorg] -DLLVM_BUILD_32_BITS=ON \
[llvmorg] -DLLVM_BUILD_TOOLS=ON \
[llvmorg] -DLLVM_ENABLE_RTTI=ON\n\
[llvmorg] cd build\n\
[llvmorg] make install\n\
[mesa] patch -p1 < ../patches/`basename \$PWD`.patch\n\
[mesa] find -name 'meson.build' -exec sed -i 's/shared_library(/library(/' {} \\;\n\
[mesa] find -name 'meson.build' -exec sed -i 's/name_suffix : .so.,//' {} \\;\n\
[mesa] sed -i 's/extra_libs_libglx = \\[\\]/extra_libs_libglx = \\[libgallium_dri\\]/' src/glx/meson.build\n\
[mesa] sed -i 's/extra_deps_libgl = \\[\\]/extra_deps_libgl = \\[meson.get_compiler('\"'\"'cpp'\"'\"').find_library('\"'\"'stdc++'\"'\"')\\]/' src/glx/meson.build\n\
[mesa] sed -i 's/driver_swrast/driver_swrast, meson.get_compiler('\"'\"'cpp'\"'\"').find_library('\"'\"'stdc++'\"'\"'),/' src/gallium/targets/osmesa/meson.build\n\
[mesa] echo '#!/usr/bin/env python3' > bin/install_megadrivers.py\n\
[mesa] echo >> /bin/install_megadrivers.py\n\
[mesa] meson setup build $MESON_PROLOGUE \
-Dplatforms=x11 \
-Dgallium-drivers=swrast,i915,iris,crocus,nouveau \
-Dgallium-vdpau=disabled \
-Dgallium-omx=disabled \
-Dgallium-va=disabled \
-Dgallium-xa=disabled \
-Dvulkan-drivers=\"\" \
-Dshared-glapi=enabled \
-Dgles1=disabled \
-Dgles2=disabled \
-Dglx=dri \
-Dgbm=disabled \
-Degl=disabled \
-Dllvm=`if [ -z \"$WITH_GALLIUM\" ]; then echo disabled; else enabled; fi` \
-Dshared-llvm=disabled \
-Dlibunwind=enabled \
-Dosmesa=true\n\
[mesa] cd build\n\
[mesa] meson compile OSMesa GL glapi gallium_dri\n\
[mesa] meson install --no-rebuild\n\
[ogg] ./autogen.sh\n\
[ogg] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[ogg] make install\n\
[vorbis] ./autogen.sh\n\
[vorbis] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[vorbis] make install\n\
[flac] ./autogen.sh\n\
[flac] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[flac] make install\n\
[opus] ./autogen.sh\n\
[opus] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[opus] make install\n\
[libsndfile] sed -i '/AC_SUBST(EXTERNAL_MPEG_REQUIRE)/ a AC_SUBST(EXTERNAL_MPEG_LIBS)' configure.ac\n\
[libsndfile] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static\n\
[libsndfile] make install\n\
[cups] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --libdir=/usr/local/lib --disable-shared --enable-static --with-components=libcups\n\
[cups] make install\n\
[v4l-utils] $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --disable-v4l-utils\n\
[v4l-utils] make install\n\
[gst-build] sed -i 's/= *both_libraries(/= static_library(/' meson.build\n\
[gst-build] meson setup build $MESON_PROLOGUE \
-Ddevtools=disabled \
-Dgst-examples=disabled \
-Dtests=disabled \
-Dexamples=disabled \
-Dintrospection=disabled \
-Ddoc=disabled \
-Dgtk_doc=disabled\n\
[gst-build] ninja -C build install\n\
[gst-build] export PKG_CONFIG_PATH=/usr/local/lib/gstreamer-1.0/pkgconfig\n\
[libpcap] $CONFIGURE_FLAGS DBUS_LIBS=\"`pkg-config --libs --static dbus-1`\" ./configure --prefix=/usr/local --disable-shared\n\
[libpcap] make install\n\
[openldap] echo $CONFIGURE_FLAGS ./configure $CONFIGURE_PROLOGUE --disable-shared --enable-static --disable-debug --disable-slapd\n\
[openldap] echo make install\n\
[sane-project] echo Hello, World!"

ARG DEFAULT_BUILD_SCRIPT="\
#!/bin/sh\n\
set -e\n\
ENABLE_STATIC_ARG=\n\
DISABLE_SHARED_ARG=\n\
DISABLE_DOCS_ARG=\n\
./configure --help | grep -q '\-\-enable\-static'\n\
if [ \$? -eq 0 ]; then ENABLE_STATIC_ARG=--enable-static; fi\n\
./configure --help | grep -q '\-\-enable-shared\|\-\-disable\-shared'\n\
if [ \$? -eq 0 ]; then DISABLE_SHARED_ARG=--disable-shared; fi\n\
./configure --help | grep -q '\-\-enable-docs\|\-\-disable\-docs'\n\
if [ \$? -eq 0 ]; then DISABLE_DOCS_ARG=--disable-docs; fi\n\
./configure $CONFIGURE_PROLOGUE \
  \$ENABLE_STATIC_ARG \
  \$DISABLE_SHARED_ARG \
  \$DISABLE_DOCS_ARG \
  $CONFIGURE_FLAGS\n\
ENABLE_STATIC_ARG=\n\
DISABLED_SHARED_ARG=\n\
DISABLE_DOCS_ARG=\n\
make install\n"

# pkg_file         = xcb-proto-1.14.1.tar.gz
# pkg_name         = xcb-proto
# pkg_dir          = xcb-proto-1.14.1
# pkg_build_script = xcb-proto-1.14.1.sh

RUN mkdir -p build && \
    cd build && \
    # The packages.txt files contains 1 line for every dependency to build.
    # Each line is in one of the following formats:
    #
    # 1. <URL>
    # 2. <URL> <file name>
    # 3. <URL ending on .git> <branch name> <directory name>
    #
    # In the first case, the package name is derived from the URL, in cases
    # where it's not possible, the file name of the package is given directly.
    # For git repositories, the package name is derived from the directory
    # name by appending .tar.gz.
    #
    (for pkg_file in `sed 's/.*\///' packages.txt | awk '{print $3 ? ($3 ".tar.gz") : ($2 ? $2 : $1)}' | tr '\n' ' '`; \
     do \
       pkg_name=`echo "$pkg_file" | sed 's/\(.\{1,\}\)-[0-9]\{1,\}\(\.[0-9]\{1,\}\)*.*/\1/'`; \
       pkg_dir=`echo "$pkg_file" | sed 's/\.tar\.\(gz\|xz\|bz2\)$//'`; \
       pkg_build_script="${pkg_dir}.sh"; \
       echo "pkg_name:         $pkg_name"; \
       echo "pkg_dir:          $pkg_dir"; \
       echo "pkg_build_script: $pkg_build_script"; \
       tar -xvf "$pkg_file" || exit; \
       { echo -e "$DEP_BUILD_SCRIPTS" | grep "^\[$pkg_name\]" | sed "s/^\[$pkg_name\] //" > "$pkg_build_script"; } || exit; \
       if [ ! -s "$pkg_build_script" ]; \
       then \
         echo -e "$DEFAULT_BUILD_SCRIPT" > "$pkg_build_script" || exit; \
       else \
         echo -e "#!/bin/sh\nset -e\n`cat $pkg_build_script`" > "$pkg_build_script" || exit; \
       fi; \
       pushd "$pkg_dir" && cat "../$pkg_build_script" && . "../$pkg_build_script" && set +e && popd || exit; \
     done)
