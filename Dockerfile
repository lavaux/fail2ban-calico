FROM debian:stable-slim AS builder
ARG TARGETARCH
#ARG S6_OVERLAY_VERSION=3.1.6.2
#ARG S6_OVERLAY_RELEASE=https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-${TARGETARCH}.tar.g#z
ARG S6_OVERLAY_RELEASE=https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-x86_64.tar.xz
ADD ${S6_OVERLAY_RELEASE} /tmp/s6overlay.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-noarch.tar.xz /tmp/s6overlay-noarch.tar.xz
RUN apt-get update -y -q && apt-get install -y -q --no-install-recommends build-essential ca-certificates gcc curl
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
COPY . /builder
RUN . "$HOME/.cargo/env" && cd /builder && cargo build --release && cp target/release/fail2ban-calico /usr/bin/fail2ban-calico

RUN echo "Built ${TARGETARCH}"

#FROM --platform=linux/amd64 debian:stable-slim AS debian-amd64
#ARG TARGETARCH
##ARG S6_OVERLAY_VERSION=3.1.6.2
#ARG S6_OVERLAY_RELEASE=https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz
##ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.gz /tmp/s6overlay.tar.gz
#ADD ${S6_OVERLAY_RELEASE} /tmp/s6overlay.tar.gz
#COPY ./x86_64-unknown-linux-gnu/release/fail2ban-calico /usr/bin/fail2ban-calico
#RUN echo "Built ${TARGETARCH}"
#
#ARG FAIL2BAN_CALICO=./x86_64-unknown-linux-gnu/release/fail2ban-calico
#ARG FAIL2BAN_CALICO
#ARG S6_OVERLAY_RELEASE

FROM debian:stable-slim
ARG TARGETARCH

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y -q && \
    apt-get install -y -q --no-install-recommends\
    fail2ban \
    exim4 \
    xz-utils \
    bsd-mailx \
    whois \
    && rm -rf /var/lib/apt/lists/*

# Copy architecture-specific files
COPY --from=builder /tmp/s6overlay.tar.xz /tmp/
COPY --from=builder /tmp/s6overlay-noarch.tar.xz /tmp/
COPY --from=builder /usr/bin/fail2ban-calico /usr/bin/

RUN tar -xJf /tmp/s6overlay.tar.xz -C / \
    && rm /tmp/s6overlay.tar.xz && \
    tar -xJf /tmp/s6overlay-noarch.tar.xz -C / \
    && rm /tmp/s6overlay-noarch.tar.xz && \
    chmod +x /usr/bin/fail2ban-calico

# Add rootfs and fail2ban-calico
ADD rootfs /

ENTRYPOINT [ "/init" ]
