#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --tun=userspace-networking \
    --socks5-server=0.0.0.0:10086 \
    --state=/var/lib/tailscale/tailscaled.state \
    >> /dev/stdout &
    
if [ -n "$HEADSCALE_LOGIN_SERVER" ]; then
    /usr/bin/tailscale up \
        --accept-routes=false \
        --accept-dns=false \
        --login-server=$HEADSCALE_LOGIN_SERVER \
        --auth-key $TAILSCALE_AUTH_KEY \
        --netfilter-mode=off \
        --hostname=$TAILSCALE_HOSTNAME \
        >> /dev/stdout &
else
    /usr/bin/tailscale up \
        --accept-routes=false \
        --accept-dns=false \
        --auth-key $TAILSCALE_AUTH_KEY \
        --netfilter-mode=off \
        --hostname=$TAILSCALE_HOSTNAME \
        >> /dev/stdout &
fi

#Check for and or create certs directory
if [ ! -d "/root/derper/ssl" ]; then
    echo "Certs directory not found, creating..."   
    mkdir -p /root/derper/ssl
fi

echo "Starting DERP server with the following configuration:"
echo "Hostname: $TAILSCALE_DERP_HOSTNAME"
echo "Cert Mode: $TAILSCALE_DERP_CERTMODE"
echo "DERP Address: $DERP_ADDR"
echo "STUN Port: $DERP_STUN_PORT"
echo "HTTP Port: $DERP_HTTP_PORT"
echo "Verify Clients: $TAILSCALE_DERP_VERIFY_CLIENTS"

# Check if TAILSCALE_DERP_HOSTNAME is an IPv4 address
IS_IPV4=$(echo "$TAILSCALE_DERP_HOSTNAME" | grep -Ec '^([0-9]{1,3}\.){3}[0-9]{1,3}$')

if [ "$IS_IPV4" -eq 1 ]; then
    echo "Hostname is an IPv4 address ,switch to self sign mode."
    # Switch certmode to manual if not already
    if [ "$TAILSCALE_DERP_CERTMODE" != "manual" ]; then
        echo "Certmode is '$TAILSCALE_DERP_CERTMODE', switching to manual mode..."
        TAILSCALE_DERP_CERTMODE="manual"
    fi
    
    # Generate private key if not exists
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key" ]; then
        echo "Generating private key..."
        openssl genrsa -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key 4096
    else
        echo "Private key already exists, skipping..."
    fi
       
    # Generate CSR if not exists
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr" ]; then
        echo "Generating CSR..."
        openssl req -new \
            -key /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key \
            -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr \
            -subj "/CN=$TAILSCALE_DERP_HOSTNAME" \
            -addext "subjectAltName=IP:$TAILSCALE_DERP_HOSTNAME"
    else
        echo "CSR already exists, skipping..."
    fi
    
    # Generate self-signed certificate if not exists (100 years)
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.crt" ]; then
        echo "Generating self-signed certificate (100 years)..."
        openssl x509 -req \
            -in /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr \
            -signkey /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key \
            -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.crt \
            -days 36500 \
            -extfile <(printf "subjectAltName=IP:$TAILSCALE_DERP_HOSTNAME")
    else
        echo "Certificate already exists, skipping..."
    fi
fi

#Start Tailscale derp server
/root/go/bin/derper --hostname=$TAILSCALE_DERP_HOSTNAME \
    --certmode=$TAILSCALE_DERP_CERTMODE \
    --certdir=/root/derper/ssl \
    --a=:$DERP_ADDR \
    --stun=true \
    --stun-port=$DERP_STUN_PORT \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS
