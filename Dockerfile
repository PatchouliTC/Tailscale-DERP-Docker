FROM alpine:latest AS builder

LABEL org.opencontainers.image.source https://github.com/PatchouliTC/Tailscale-DERP-Docker

#Install GO and Tailscale DERPER
RUN apk add go --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
RUN go install tailscale.com/cmd/derper@latest

FROM alpine/openssl:latest

#Install Tailscale and Tailscaled
RUN apk add --no-cache curl iptables tailscale --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community && \
    rm -rf /var/cache/apk/*

#Copy Tailscale DERPER binary
RUN mkdir -p /root/go/bin
COPY --from=builder /root/go/bin/derper /root/go/bin/derper

#Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

ENTRYPOINT /init.sh
