# The stack's services in one image: kata's daemon and the owcli, bossman,
# and goatlassian web UIs, with all state in the /kgbo volume (the data
# bundle, reached through the home variables, never symlinks).
# Build from the repository root: make image

ARG GO_VERSION=1.22

FROM docker.io/library/golang:${GO_VERSION}-bookworm AS build
ARG OWCLI_VERSION=v0.4.0
ARG BOSSMAN_VERSION=v0.2.0
ARG GOATLASSIAN_VERSION=v0.3.0
ARG KATA_VERSION=0.18.0
# kata publishes no checksum file; these are of the pinned release.
ARG KATA_SHA256_amd64=bda4a6a24b74c1ee71be1237ce2e16ff6f627c6e5bee67fcb97525d3b2abe052
ARG KATA_SHA256_arm64=16ddcb25df5212469fd49fd19c2e3d2f9e6d8d552ebe09824cf22b7135b80674
ARG TARGETARCH=amd64
ENV CGO_ENABLED=0 GOBIN=/out GOFLAGS=-trimpath
RUN go install github.com/Hoodoo/owcli/cmd/owcli@${OWCLI_VERSION} \
 && go install github.com/Hoodoo/bossman/cmd/bossman@${BOSSMAN_VERSION} \
 && go install github.com/Hoodoo/goatlassian/cmd/goatlassian@${GOATLASSIAN_VERSION}
RUN set -eu; \
    sum=$(eval echo "\$KATA_SHA256_${TARGETARCH}"); \
    curl -fsSL -o /tmp/kata.tgz "https://github.com/kenn-io/kata/releases/download/v${KATA_VERSION}/kata_${KATA_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    echo "${sum}  /tmp/kata.tgz" | sha256sum -c -; \
    tar -xzf /tmp/kata.tgz -C /out kata

FROM docker.io/library/debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl git python3 tini \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 1000 --create-home kgbo
COPY --from=build /out/ /usr/local/bin/
# bin/kgbo and its manifest: snapshots and remap on the server.
COPY stack.toml /opt/kgbo-stack/stack.toml
COPY bin/kgbo /opt/kgbo-stack/bin/kgbo
# The bundle's home variables, set for every process (services, exec, health
# check): one that missed them would use the defaults, and kata would start a
# second daemon there. The build fails if they drift from stack.toml.
ENV KGBO_HOME=/kgbo \
    KATA_HOME=/kgbo/kata \
    OWCLI_HOME=/kgbo/owcli \
    BOSSMAN_HOME=/kgbo/bossman \
    GOATLASSIAN_HOME=/kgbo/goatlassian
RUN ln -s /opt/kgbo-stack/bin/kgbo /usr/local/bin/kgbo \
 && kgbo env --plain --root /kgbo | while IFS== read -r key value; do \
      [ "$(printenv "$key")" = "$value" ] || { echo "ENV $key drifted from stack.toml: want $value" >&2; exit 1; }; \
    done
COPY deploy/container/kgbo-services /usr/local/bin/kgbo-services
USER kgbo
WORKDIR /home/kgbo
VOLUME /kgbo
HEALTHCHECK --interval=1m --timeout=10s --start-period=30s CMD ["kgbo-services", "check"]
ENTRYPOINT ["tini", "--", "kgbo-services"]
