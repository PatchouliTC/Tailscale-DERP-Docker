English / [中文](README.md)

# Introduction
The aim of this repository is to create a simple and easy to use docker container with minimal setup to run your own Tailscale DERP server.  

There is two parts to the container, the tailscale client itself and the DERP server. The tailscale client is used to connect the container to your tailnet as it's own device, this allows the --verify-clients argument to be set on the derp server, this is so only devices in your own tailnet can use the DERP server, allowing it to the open internet in my opinion is a bad idea. 

In this container,tailscale will running in userspace mode---which require no NAT CAP and won't change host net config and not create tailscale net device,so you can start multi derper with verify client in same host so that one host can role relay node for multi tailscale namespace or not polluting host environment

# Container
The container is setup to pull the latest version of the DERPER application and the latest version of Tailscale each time you build the container.
```bash
docker pull ghcr.io/patchoulitc/tailscale-derp-docker:latest
```

To rebuild with the latest version in local, simple run the following commands 

```bash
docker rmi tailscale-derp-docker:1.0
docker build . -t tailscale-derp-docker:1.0
```
# Setup Details

## Ports Required
To allow full functionality of the DERP server, you will need to open/allow the following ports on your Firewall/Security Group,port which you need to open depends on how you configure derp

### 1. Use Derp self acme function to get cert

```
80:80/tcp
443:443/tcp
3478:3478/udp
```
Port 80 is for acme http-1 challenge

Port 443 is for HTTPS relay

Port 3478 is for STUN **[you can change to other port]**

### 2. Use self sign or reverse proxy

```
9000:443/tcp
3478:3478/udp
```
Port 9000 is for HTTPS relay **[you can change to other port,your reverse proxy should redirct to this port with http (http://127.0.0.1:9000 e.g)]**

Port 3478 is for STUN **[you can change to other port]**

---

**EXTRA**:there is a socks5 port 10086 for porxy---if any app what to visit current tailscale virtual network,if you have this requirement,you can map it to host port and use proxy to visit
```
10086:10086
```

## Changing the .env file variables
**IMPORTANT STEP**

Change the variables in .env file 


| Config | Default | Desc |
|--------|--------|------|
| `TAILSCALE_DERP_HOSTNAME` | `derp.example.com` | DERP Domain/ipv4 |
| `TAILSCALE_DERP_VERIFY_CLIENTS` | `true` | is verify cilent (**do not change**) |
| `HEADSCALE_LOGIN_SERVER` | `https://your.headscale.server` | tailnet login server(for headscale,empty will use the official login server) |
| `TAILSCALE_AUTH_KEY` | `ENTER YOUR TAILSCALE AUTH KEY HERE` | Tailscale preauth key |
| `TAILSCALE_HOSTNAME` | `derp-client` | DERP client hostname [displayed in the tailscale client list and used for naming the container and network] |
| `DERP_ADDR` | `443` | DERP listen addr (**do not change due to port mapping**) |
| `DERP_STUN_PORT` | `3478` | DERP STUN port (**do not change due to port mapping**) |
| `DERP_HTTP_PORT` | `80` | DERP HTTP port (**do not change due to port mapping**) |
| `TAILSCALE_DERP_CERTMODE` | `manual` | self sign or reverse proxy set `manual`,use derp acme set `letsencrypt` |


## Building Docker Image
```
docker build . -t tailscale-derp-docker:1.0
```

## Starting the image
```
docker compose up -d
```

## Changing the Tailscale ACL / Headscale derp.yml
Once your Tailscale DERP server is operational and you can see the new device in the devices section of the Tailscale admin console, You need to change your ACL to only allow the use of your DERP server and omit out the default Tailscale servers. This can be done by adding the following config at the bottom of your ACL file.

```
	"derpMap": {
		"OmitDefaultRegions": true,
		"Regions": {
			"900": {
				"RegionID":   900,
				"RegionCode": "myderpserver",
				"Nodes": [
					{
						"Name":     "1",
						"RegionID": 900,
						"HostName": "derp.example.com",
						"ipv4": "server-ipv4 if have",
						"ipv6": "server-ipv6 if have",
						"stunport": "mapping stunport,set -1 to disable stun for this node",
						"stunonly": "true if this node only use for stun else false",
						"derpport": "derp listening port",
						"CanPort80": "false",
						"InsecureForTests": "true if use self sign ip cert",
						"CertName": "add this field if use self sign ip cert,after container up,copy certs/certname.txt context into there"
					},
				],
			},
		},
	},
```
If using Headscale, consider directly modifying the derp.yaml file
```
regions:
 900:
  regionid: 900
  regioncode: myderpserver
  regionname: myderpserver
  nodes:
   - name: 1
     regionid: 900
     hostname: derp.example.com
     ipv4: <server IPv4 address if have>
     ipv6: <server IPv6 address if have>
     stunport: <mapping stunport, set -1 to disable stun for this node>
     stunonly: <true if this node only use for stun else false>
     derpport: <derp listening port>
	 CanPort80: false
	 InsecureForTests: <true if use self sign ip cert>
	 CertName: <add this field if use self sign ip cert,after container up,copy certs/certname.txt context into there>
```

More information can be found here [Tailscale DERP server docs](https://tailscale.com/kb/1118/custom-derp-servers/) on setting this config.  

## Additional Notes and Explanations
1. Since tailscaled modifies UDP read/write buffer by default, which requires CAP_NET_ADMIN capability and causes host network configuration changes, the docker-compose file comments out this configuration by default. If you don't mind this configuration change, you can uncomment it before starting **[if not modified, an error will be shown during startup, but it only affects throughput, not the startup itself]**
2. When using self-signed certificates, DERP will check tailscale.sock when a relay request arrives. If the node key of the request is not in the records [i.e., the requester is not a member of the virtual network where the current tailscale client is located], the relay will be refused. Self-signed certificates only affect the TLS encryption verification during transmission
3. The DERP server also provides STUN functionality. STUN can be understood as a negotiator that records the public IP addresses of all connected devices from the public network perspective. When devices attempt to connect directly to each other, the STUN node will distribute the public access addresses to both parties for mutual connection attempts. Therefore, if there is no DERP node with an IPv6 address and STUN functionality enabled in a tailscale network, all devices in that network will be unable to attempt any IPv6 direct connections [shown as "no" for IPv6 address in tailscale netcheck]. The same applies to IPv4
4. As written in the configuration, users can configure DERP nodes as pure STUN negotiation nodes or pure DERP relay nodes
   
   - Pure STUN negotiation node: set stunonly to true
   - Pure DERP node: set stunport to -1
