# Build stage to build Wine from source
FROM quay.io/lib/debian:trixie AS builder

# Setup temporary package proxy
RUN echo 'Acquire::http::Proxy "http://host.docker.internal:3142";' > /etc/apt/apt.conf.d/00aptproxy
# Install build dependencies
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
        libudev-dev \
        libunwind-dev \
        libx11-dev \
        libfreetype-dev \
        libxcomposite-dev \
        libxcursor-dev \
        libxfixes-dev \
        libxi-dev \
        libxrandr-dev \
        libxrender-dev \
        libxext-dev \
        libxkbcommon-dev \
        libxkbregistry-dev \
        make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Prepare Wine source
#RUN curl -L https://dl.winehq.org/wine/source/10.x/wine-10.6.tar.xz | tar -xJf - && \
ADD wine-10.6.tar.xz /build/
RUN mkdir pkgdir

ARG CFLAGS="-Os -pipe -g"
ARG CXXFLAGS="-Os -pipe -g"
ARG LDFLAGS="-Wl,-O1"

# Build Wine
WORKDIR /build/wine-10.6
RUN autoreconf && \
    ./configure \
    --enable-archs=i386,x86_64 \
    --disable-tests \
    --disable-win16 \
    --disable-winedbg \
    --prefix=/usr
RUN make -j$(nproc)

# Package Wine
RUN make DESTDIR=/build/pkgdir/ install

# Strip unneeded symbols
RUN find /build/pkgdir/usr/bin /build/pkgdir/usr/lib/wine -type f -exec strip --strip-unneeded {} \;
# Remove unnecessary files
#RUN rm -r /build/pkgdir/usr/share/wine \
#           /build/pkgdir/usr/bin/regedit /build/pkgdir/usr/bin/winefile \
#           /build/pkgdir/usr/lib/wine/*-windows/*d3d* \
#           /build/pkgdir/usr/lib/wine/*-windows/*gdi* \
#           /build/pkgdir/usr/lib/wine/*-windows/*opengl* \
#           /build/pkgdir/usr/lib/wine/*-windows/*audio* \
#           /build/pkgdir/usr/lib/wine/*-windows/*msstyles \
#           /build/wine*

FROM quay.io/lib/debian:trixie-slim

RUN echo 'Acquire::http::Proxy "http://host.docker.internal:3142";' > /etc/apt/apt.conf.d/00aptproxy
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash \
    libunwind8 \
    libxext6 \
    xauth \
    xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy executable binaries
#COPY --from=localhost/winebuild /build/pkgdir/usr/bin/wine /usr/bin/
#COPY --from=localhost/winebuild /build/pkgdir/usr/bin/wineserver /usr/bin/
#COPY --from=localhost/winebuild /usr/bin/Xvfb /usr/bin/
#COPY --from=localhost/winebuild /usr/bin/xvfb-run /usr/bin/

# Copy DLLs
COPY --from=builder /build/pkgdir/usr /usr/

CMD ["bash"]

