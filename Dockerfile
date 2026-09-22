# =============================================================================
# Multi-stage build
# =============================================================================
# Stage 1 has a full toolchain (~1.2 GB). Stage 2 copies out one binary and
# keeps only the runtime libraries. Nothing from the builder reaches the final
# image unless you explicitly COPY it, so the compiler, headers and sources
# never ship.
#
# Compare this to ../diskmon/Dockerfile: Go cross-compiles to a static binary
# with CGO_ENABLED=0, so its runtime stage is a bare alpine with one file in it
# (~10 MB). C++ links dynamically against libcurl and libstdc++, so you need a
# runtime stage that actually has them (~90 MB). That gap is the real cost of
# the rewrite, and it is worth understanding rather than just accepting.
#
# If you want to close it later, in rough order of effort:
#   - `-static-libstdc++ -static-libgcc` drops the libstdc++ dependency
#   - fully static against musl on alpine: possible, but static OpenSSL for
#     libcurl's TLS is genuinely fiddly -- save it for when you are bored
#   - a distroless or scratch base once the binary is truly static
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: build
# -----------------------------------------------------------------------------
# Debian 13 (trixie) ships GCC 14, which has complete C++20 support including
# <format>, <stop_token> and std::jthread. Bookworm's GCC 12 does NOT have
# <format> and will fail confusingly -- do not "helpfully" downgrade this.
FROM debian:trixie AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        libcurl4-openssl-dev \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy the build definition before the sources. Docker caches each layer, so
# as long as these two files are unchanged, editing a .cpp does not invalidate
# anything above this line. With FetchContent that matters more than usual --
# it is the difference between recompiling Catch2 on every build and not.
COPY CMakeLists.txt ./
COPY tests/CMakeLists.txt tests/

COPY include/ include/
COPY src/ src/
COPY tests/ tests/

# Deliberately NOT using --preset here. Presets are a developer-ergonomics tool
# tuned for your Mac; a container build wants its flags stated explicitly and
# pinned. Note DISKMON_BUILD_TESTS=OFF -- this stage should not be downloading
# Catch2 from GitHub. Run tests in CI or locally, not in the image build, where
# a network blip becomes a deploy failure.
RUN cmake -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DDISKMON_BUILD_TESTS=OFF \
        -DDISKMON_SANITIZE=OFF \
    && cmake --build build --parallel

# -----------------------------------------------------------------------------
# Stage 2: runtime
# -----------------------------------------------------------------------------
FROM debian:trixie-slim

# libcurl4 is the runtime library (no headers); ca-certificates is required or
# every https:// call to ntfy fails certificate verification. The Go image
# needed ca-certificates for exactly the same reason.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcurl4 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Run as a non-root user. diskmon only ever READS the host filesystem (the
# compose file mounts / at /hostfs:ro) and talks to qBittorrent over HTTP, so
# it has no need for root.
#
# There is a subtlety worth knowing: this is also why the f_bavail choice in
# disk.hpp is the correct one. As an unprivileged user, the root-reserved
# blocks genuinely are not available to this process -- f_bavail reports what
# it can actually use.
RUN useradd --system --no-create-home --uid 10001 diskmon
USER diskmon

COPY --from=builder /src/build/diskmon /usr/local/bin/diskmon

# ENTRYPOINT in exec form (a JSON array, not a string). Shell form wraps the
# process in /bin/sh, which does not forward signals -- your SIGTERM handler
# would never run and `docker stop` would always fall through to SIGKILL after
# 10 seconds. Having written the stop_token shutdown, this one line is what
# decides whether it ever executes.
ENTRYPOINT ["/usr/local/bin/diskmon"]
