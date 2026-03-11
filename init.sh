#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state >> /dev/stdout &
sleep 2

STATUS=$(/usr/bin/tailscale status 2>&1)
if echo "$STATUS" | grep -qE "Logged out|stopped|not logged in"; then
    echo "Tailscale is not logged in, performing login..."
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
else
    echo "Tailscale is already logged in, skipping login."
    /usr/bin/tailscale status
fi

#Check for and or create certs directory
if [ ! -d "/root/derper/$TAILSCALE_DERP_HOSTNAME" ]; then
    echo "Certs directory not found, creating..."   
    mkdir -p /root/derper/$TAILSCALE_DERP_HOSTNAME
fi

#Create tun folder if it doesn't exist
if [ ! -d "/dev/net/tun" ]; then
    echo "Creating /dev/net directory..."
    mkdir -p /dev/net/tun
fi


#Start Tailscale derp server
/root/go/bin/derper \
--hostname $TAILSCALE_DERP_HOSTNAME \
--bootstrap-dns-names $TAILSCALE_DERP_HOSTNAME \
--certmode $TAILSCALE_DERP_CERTMODE \
--certdir /root/derper/$TAILSCALE_DERP_HOSTNAME \
--stun \
--verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS
