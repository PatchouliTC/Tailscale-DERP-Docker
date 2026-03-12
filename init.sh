#!/usr/bin/env sh

#Start tailscaled and connect to tailnet
/usr/sbin/tailscaled --tun=userspace-networking \
    --socks5-server=0.0.0.0:10086 \
    --state=/var/lib/tailscale/tailscaled.state \
    >> /dev/stdout &

until /usr/bin/tailscale status 2>&1 | grep -qv "failed to connect"; do
    echo "---Waiting for tailscaled to be ready..."
    sleep 1
done

echo "------------------------------------------------------"

TS_STATUS=$(/usr/bin/tailscale status 2>&1)
NEED_AUTH=""
if echo "$TS_STATUS" | grep -q "Logged out"; then
    echo "---Tailscale is logged out, will use auth-key to login."
    NEED_AUTH="--auth-key $TAILSCALE_AUTH_KEY"
else
    echo "---Tailscale is already logged in, skipping auth-key."
fi

if [ -n "$HEADSCALE_LOGIN_SERVER" ]; then
    /usr/bin/tailscale up \
        --accept-routes=false \
        --accept-dns=false \
        --login-server=$HEADSCALE_LOGIN_SERVER \
        $NEED_AUTH \
        --netfilter-mode=off \
        --hostname=$TAILSCALE_HOSTNAME \
        >> /dev/stdout
else
    /usr/bin/tailscale up \
        --accept-routes=false \
        --accept-dns=false \
        $NEED_AUTH \
        --netfilter-mode=off \
        --hostname=$TAILSCALE_HOSTNAME \
        >> /dev/stdout
fi

# Set relay server port if configured (only when login was performed)
if [ -n "$NEED_AUTH" ]; then
    if [ -n "$PEER_RELAY_SERVER_PORT" ]; then
        echo "---Enabling relay server on port $PEER_RELAY_SERVER_PORT..."
        /usr/bin/tailscale set --relay-server-port="$PEER_RELAY_SERVER_PORT"
    fi
else
    echo "---Disabling relay server..."
    /usr/bin/tailscale set --relay-server-port=""
fi

echo "------------------------------------------------------"

#Check for and or create certs directory
if [ ! -d "/root/derper/ssl" ]; then
    echo "---Certs directory not found, creating..."   
    mkdir -p /root/derper/ssl
fi

echo "------------------------------------------------------"
echo "Starting DERP server with the following configuration:"
echo "Hostname: $TAILSCALE_DERP_HOSTNAME"
echo "Cert Mode: $TAILSCALE_DERP_CERTMODE"
echo "DERP Address: $DERP_ADDR"
echo "STUN Port: $DERP_STUN_PORT"
echo "HTTP Port: $DERP_HTTP_PORT"
echo "Verify Clients: $TAILSCALE_DERP_VERIFY_CLIENTS"
echo "------------------------------------------------------"

# Check if TAILSCALE_DERP_HOSTNAME is an IPv4 address
IS_IPV4=$(echo "$TAILSCALE_DERP_HOSTNAME" | grep -Ec '^([0-9]{1,3}\.){3}[0-9]{1,3}$')

if [ "$IS_IPV4" -eq 1 ]; then
    echo "---Hostname is an IPv4 address ,switch to self sign mode."
    # Switch certmode to manual if not already
    if [ "$TAILSCALE_DERP_CERTMODE" != "manual" ]; then
        echo "---Certmode is '$TAILSCALE_DERP_CERTMODE', switching to manual mode..."
        TAILSCALE_DERP_CERTMODE="manual"
    fi
    
    # Generate private key if not exists
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key" ]; then
        echo "---Generating private key..."
        openssl genrsa -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key 4096
    else
        echo "---Private key already exists, skipping..."
    fi
       
    # Generate CSR if not exists
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr" ]; then
        echo "---Generating CSR..."
        openssl req -new \
            -key /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key \
            -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr \
            -subj "/CN=$TAILSCALE_DERP_HOSTNAME" \
            -addext "subjectAltName=IP:$TAILSCALE_DERP_HOSTNAME"
    else
        echo "---CSR already exists, skipping..."
    fi
    
    # Generate self-signed certificate if not exists (100 years)
    if [ ! -f "/root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.crt" ]; then
        echo "---Generating self-signed certificate (100 years)..."
        openssl x509 -req \
            -in /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.csr \
            -signkey /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.key \
            -out /root/derper/ssl/$TAILSCALE_DERP_HOSTNAME.crt \
            -days 36500 \
            -extfile <(printf "subjectAltName=IP:$TAILSCALE_DERP_HOSTNAME")
    else
        echo "---Certificate already exists, skipping..."
    fi
fi

echo "------------------------------------------------------"

#Start Tailscale derp server
/root/go/bin/derper --hostname=$TAILSCALE_DERP_HOSTNAME \
    --certmode=$TAILSCALE_DERP_CERTMODE \
    --certdir=/root/derper/ssl \
    --a=:$DERP_ADDR \
    --stun=true \
    --stun-port=$DERP_STUN_PORT \
    --http-port=$DERP_HTTP_PORT \
    --verify-clients=$TAILSCALE_DERP_VERIFY_CLIENTS 2>&1 | while IFS= read -r line; do
    echo "$line"
    # 检查是否包含 CertName
    case "$line" in
        *'"CertName"'*)
            CERT_NAME=$(echo "$line" | sed -n 's/.*"CertName":"\([^"]*\)".*/\1/p')
            if [ -n "$CERT_NAME" ]; then
                echo "$CERT_NAME" > /root/derper/ssl/certname.txt
                echo "---CertName extracted and saved: $CERT_NAME"
            fi
            ;;
    esac
done
