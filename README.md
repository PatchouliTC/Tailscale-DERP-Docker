# Introduction
The aim of this repository is to create a simple and easy to use docker container with minimal setup to run your own Tailscale DERP server.  

There is two parts to the container, the tailscale client itself and the DERP server. The tailscale client is used to connect the container to your tailnet as it's own device, this allows the --verify-clients argument to be set on the derp server, this is so only devices in your own tailnet can use the DERP server, allowing it to the open internet in my opinion is a bad idea. 

In this container,tailscale will running in userspace mode---which require no NAT CAP and won't change host net config and not create tailscale net device,so you can start multi derper with verify client in same host so that one host can play relay node for multi tailscale namespace

# Container
The container is setup to pull the latest version of the DERPER application and the latest version of Tailscale each time you build the container.

To rebuild with the latest version simple run the following commands
```bash
docker rmi tailscale-derp-docker:1.0
docker build . -t tailscale-derp-docker:1.0
```
# Setup Details

## Ports Required
To allow full functionality of the DERP server, you will need to open/allow the following ports on your Firewall/Security Group

```
443:443/tcp
3478:3478/udp
```

Port 3478 is for STUN **[for multi tailscale namespace use,3478 port do not mapping into host,STUN port just use for check other client could be connect direct,you can use other derp node to check this]**

Port 443 is for HTTPS relay **[Suggest deploy reverse proxy front containers]**

**EXTRA**:there is a socks5 port 10086 for porxy---if any app what to visit current tailscale virtual network,if you have this requirement,you can map it to host port and use proxy to visit

## Changing the .env file variables
**IMPORTANT STEP**

Change the variables in .env file 

## Building Docker Image
```
docker build . -t tailscale-derp-docker:1.0
```

## Starting the image
```
docker compose up -d
```

## Changing the Tailscale ACL
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
					},
				],
			},
		},
	},
```

More information can be found here [Tailscale DERP server docs](https://tailscale.com/kb/1118/custom-derp-servers/) on setting this config.  
