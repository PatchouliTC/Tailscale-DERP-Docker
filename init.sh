#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --tun=userspace-networking --socks5-server=0.0.0.0:10086 --state=/var/lib/tailscale/tailscaled.state >> /dev/stdout &
/usr/bin/tailscale up \
    --accept-routes=false \
    --accept-dns=false \
    --login-server=$HEADSCALE_LOGIN_SERVER \
    --auth-key $TAILSCALE_AUTH_KEY \
    --netfilter-mode=off \
    --hostname=$TAILSCALE_HOSTNAME \
    >> /dev/stdout &

#Check for and or create certs directory
if [ ! -d "/root/derper/$TAILSCALE_DERP_HOSTNAME" ]; then
    echo "Certs directory not found, creating..."   
    mkdir -p /root/derper/$TAILSCALE_DERP_HOSTNAME
fi

echo "Starting DERP server with the following configuration:"
echo "Hostname: $TAILSCALE_DERP_HOSTNAME"
echo "Cert Mode: $TAILSCALE_DERP_CERTMODE"
echo "Cert Directory: /root/derper/$TAILSCALE_DERP_HOSTNAME"
echo "DERP Address: $DERP_ADDR"
echo "STUN Port: $DERP_STUN_PORT"
echo "HTTP Port: $DERP_HTTP_PORT"
echo "Verify Clients: $TAILSCALE_DERP_VERIFY_CLIENTS"

#Start Tailscale derp server
/root/go/bin/derper \
    --hostname=$TAILSCALE_DERP_HOSTNAME \
    #--bootstrap-dns-names=$TAILSCALE_DERP_HOSTNAME \
    --certmode=$TAILSCALE_DERP_CERTMODE \
    --certdir=/root/derper/$TAILSCALE_DERP_HOSTNAME \
    --a=$DERP_ADDR \
    --stun=true \
    --stun-port=$DERP_STUN_PORT \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS
