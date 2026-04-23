# Using multi-stage builds for smaller images

FROM alpine as builder

RUN apk add --no-cache \
        gcc \
        libc-dev \
        linux-headers \
        git \
        make \
        bash \
        curl \
        openssh-client \
        openssl \
        musl-dev

FROM ubuntu:20.04

# Consolidated package installation
RUN apt-get update && apt-get install -y \
        build-essential \
        git \
        curl \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/output /app/output

CMD ["/app/output" ]