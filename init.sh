#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state >> /dev/stdout &
/usr/bin/tailscale up \
--accept-routes=false \
--accept-dns=false \
--login-server=$HEADSCALE_LOGIN_SERVER \
--auth-key $TAILSCALE_AUTH_KEY \
--tun=userspace-networking \
--netfilter-mode=off \
--hostname=$TAILSCALE_HOSTNAME \
--socks5-server=0.0.0.0:10086 \
>> /dev/stdout &

#Check for and or create certs directory
mkdir -p /root/derper/$TAILSCALE_DERP_HOSTNAME

#Start Tailscale derp server
/root/go/bin/derper \
--hostname $TAILSCALE_DERP_HOSTNAME \
--bootstrap-dns-names $TAILSCALE_DERP_HOSTNAME \
--certmode $TAILSCALE_DERP_CERTMODE \
--certdir /root/derper/$TAILSCALE_DERP_HOSTNAME \
--stun \
--verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS
