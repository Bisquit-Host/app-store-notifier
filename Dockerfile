# syntax=docker/dockerfile:1.6

# Build stage  (Swift 6.3.3 + jemalloc + persistent caches)
FROM swift:6.3.3-noble AS build

# Static-link needs the development archive, not just the runtime .so
RUN apt-get -q update \
 && apt-get -q install -y --no-install-recommends libjemalloc-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# 1. Dependency resolution
COPY Package.swift Package.resolved ./
RUN --mount=type=cache,id=swiftpm,target=/root/.cache/swiftpm,sharing=locked \
    swift package resolve --force-resolved-versions

# 2. Application sources
COPY Sources ./Sources
COPY Tests ./Tests
COPY Public ./Public

# 3. Compile and stage the artifacts in one step
RUN --mount=type=cache,id=swift-build,target=/build/.build,sharing=locked \
    swift build -c release \
        --product AppStoreNotifier \
        --static-swift-stdlib \
        -Xlinker -ljemalloc \
 && mkdir -p /stage \
 && cp "$(find .build -path '*/release/AppStoreNotifier' -type f -perm -111 | head -n 1)" /stage/ \
 && cp /usr/libexec/swift/linux/swift-backtrace-static /stage/ \
 && find -L .build -path '*/release/*.resources' -exec cp -Ra {} /stage/ \; \
 && if [ -d Public ]; then mv Public /stage/Public && chmod -R a-w /stage/Public; fi

# Runtime stage  (tiny Ubuntu image)
FROM ubuntu:noble

RUN apt-get -q update \
 && apt-get -q install -y --no-install-recommends \
        libjemalloc2 \
        ca-certificates \
        tzdata \
 && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
WORKDIR /app

# Copy the staged artifacts from the builder
COPY --from=build --chown=vapor:vapor /stage /app

# Enable Swift crash backtraces
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
ENV MIGRATE_ON_START=true

USER vapor:vapor
EXPOSE 1999

ENTRYPOINT ["./AppStoreNotifier"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "1999"]
