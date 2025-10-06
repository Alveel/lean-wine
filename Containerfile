# Build stage to build Wine from source
FROM docker.io/debian:trixie-slim AS builder

# Wine version & SHA256 checksum
ARG WINE_VERSION="10.16"
ARG WINE_CHECKSUM="c5ed2742bff208c63b005bcfb91a2fc6cc49af6c6695bc8c0cf0fe6f4da60446"
# Build flags
ARG CFLAGS="-Os -pipe -g"
ARG CXXFLAGS="-Os -pipe -g"
ARG LDFLAGS="-Wl,-O1"

# Download Wine source
ADD --checksum=sha256:$WINE_CHECKSUM \
    https://dl.winehq.org/wine/source/10.x/wine-$WINE_VERSION.tar.xz /build/

# Update system & install build dependencies
RUN apt-get update && apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends --quiet \
        bison \
        build-essential \
        ca-certificates \
        curl \
        dh-autoreconf \
        flex \
        gcc-mingw-w64 \
        libgnutls28-dev \
        libpcap-dev \
        libx11-dev \
        libxrandr-dev \
        make \
        xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Extract Wine source, configure and build
RUN tar -C /build -xf /build/wine-$WINE_VERSION.tar.xz && rm /build/wine-$WINE_VERSION.tar.xz && \
    cd /build/wine-$WINE_VERSION && \
    autoreconf && \
    ./configure \
        --enable-archs=i386,x86_64 \
        --disable-tests \
        --disable-win16 \
        --disable-winedbg \
        --without-freetype \
        --without-gettext \
        --without-unwind \
        --prefix=/usr && \
    make -j$(nproc) && \
    mkdir /build/pkgdir && \
    make DESTDIR=/build/pkgdir/ install

# Strip unneeded symbols, remove unnecessary files
RUN find /build/pkgdir/usr/bin /build/pkgdir/usr/lib/wine -type f -exec strip --strip-unneeded {} \; && \
    rm -r   /build/pkgdir/usr/share/applications /build/pkgdir/usr/share/man \
            /build/pkgdir/usr/lib/wine/*-windows/*d3d* \
            /build/pkgdir/usr/lib/wine/*-windows/*opengl* \
            /build/pkgdir/usr/lib/wine/*-windows/*audio* \
            /build/pkgdir/usr/lib/wine/*-windows/*msstyles \
            /build/pkgdir/usr/lib/wine/*-windows/*mshtml* \
            /build/pkgdir/usr/lib/wine/*-windows/*msxml* \
            /build/pkgdir/usr/lib/wine/*-windows/*windowscodecs* \
            /build/pkgdir/usr/include \
            /build/wine*

# Create image from a clean Debian distribution using build files
FROM docker.io/debian:trixie-slim

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash \
    xauth \
    xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy Wine
COPY --from=builder /build/pkgdir/usr /usr/

