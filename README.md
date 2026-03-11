中文 / [English](README_EN.md)

# Tailscale-Derp-Client-Docker

# 简介
本仓库旨在创建一个简单易用的 Docker 容器，通过最少的配置即可运行你自己的 Tailscale DERP 服务器。

容器包含两个部分：Tailscale 客户端和 DERP 服务器。Tailscale 客户端用于将容器作为独立设备连接到你的 tailnet，这样可以在 DERP 服务器上设置 `--verify-clients` 参数，从而只允许你 tailnet 中的设备使用该 DERP 服务器。在我看来，将其开放到公网是不明智的。

在此容器中，Tailscale 以用户空间模式运行——这意味着不需要 NAT 需求，不会更改宿主机网络配置，也不会创建 Tailscale 网络设备。因此，你可以在同一台宿主机上启动多个带客户端验证的 DERP 服务，使一台主机可以为多个 Tailscale 命名空间充当中继节点，同时不会污染宿主机环境。

# 容器
容器设置为每次构建时拉取最新版本的 DERPER 应用程序和最新版本的 Tailscale。

要使用最新版本重新构建，只需运行以下命令：
```bash
docker rmi tailscale-derp-docker:1.0
docker build . -t tailscale-derp-docker:1.0
```

# 配置详情

## 所需端口
为了让 DERP 服务器完整运行，你需要在防火墙/安全组中开放以下端口，具体需要开放哪些端口取决于你的 DERP 配置方式。

### 1. 使用 DERP 自带的 ACME 功能获取证书

```
80:80/tcp
443:443/tcp
3478:3478/udp
```
端口 80 用于 ACME HTTP-01 验证(DERP自带一个自动化证书申请并支持自动续签)

端口 443 用于 HTTPS 中继

端口 3478 用于 STUN **【可更改为其他端口】**

### 2. 使用自签名证书或反向代理

```
9000:443/tcp
3478:3478/udp
```
端口 9000 用于 HTTPS 中继 **【可更改为其他端口，你的反向代理应将请求转发到此端口，使用 HTTP 协议（例如 http://127.0.0.1:9000）】**

端口 3478 用于 STUN **【可更改为其他端口】**

---

**额外说明**：容器内有一个 SOCKS5 代理端口 10086——如果有应用需要访问当前 Tailscale 虚拟网络，你可以将此端口映射到宿主机并通过代理访问。
```
10086:10086
```

## 修改 .env 文件变量
**重要步骤**

修改 .env 文件中的变量


| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `TAILSCALE_DERP_HOSTNAME` | `derp.example.com` | DERP 域名/ipv4地址 |
| `TAILSCALE_DERP_VERIFY_CLIENTS` | `true` | 是否验证客户端（**请勿修改**） |
| `HEADSCALE_LOGIN_SERVER` | `https://your.headscale.server` | tailnet 登录服务器（用于 Headscale，留空则使用官方登录服务器） |
| `TAILSCALE_AUTH_KEY` | `ENTER YOUR TAILSCALE AUTH KEY HERE` | Tailscale 预授权密钥 |
| `TAILSCALE_HOSTNAME` | `derp-client` | DERP 客户端主机名【显示在 Tailscale 客户端列表中，也用于容器和网络命名】 |
| `DERP_ADDR` | `443` | DERP 监听地址（**因端口映射请勿修改**） |
| `DERP_STUN_PORT` | `3478` | DERP STUN 端口（**因端口映射请勿修改**） |
| `DERP_HTTP_PORT` | `80` | DERP HTTP 端口（**因端口映射请勿修改**） |
| `TAILSCALE_DERP_CERTMODE` | `manual` | 自签名证书或反向代理设置为 `manual`，使用 DERP ACME 设置为 `letsencrypt` |


## 构建 Docker 镜像
```
docker build . -t tailscale-derp-docker:1.0
```

## 启动镜像
```
docker compose up -d
```

## 修改 Tailscale ACL / Headscale derp.yaml
当你的 Tailscale DERP 服务器运行正常，并且可以在 Tailscale 管理控制台的设备列表中看到新设备后，你需要修改 ACL 配置，使其只使用你的 DERP 服务器并禁用默认的 Tailscale 服务器。可以在 ACL 文件底部添加以下配置：

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
						"ipv4": "服务器 IPv4 地址（如果存在）",
						"ipv6": "服务器 IPv6 地址（如果存在）",
						"stunport": "映射的 STUN 端口，设置 -1 可禁用此节点的 STUN",
						"stunonly": "如果此节点仅用于 STUN 则为 true，否则为 false",
						"derpport": "DERP 监听端口",
						"CanPort80": "false",
						"InsecureForTests": "如果使用IP自签证书则为 true",
						"CertName": "仅当使用IP自签模式添加该字段,启动后将当前目录certs/certname.txt中内容复制到该字段"
					},
				],
			},
		},
	},
```
如果是headscale,考虑直接修改derp.yaml文件
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
     ipv4: <服务器 IPv4 地址（如果存在）>
     ipv6: <服务器 IPv6 地址（如果存在）>
     stunport: <映射的 STUN 端口，设置 -1 可禁用此节点的 STUN>
     stunonly: <如果此节点仅用于 STUN 则为 true，否则为 false>
     derpport: <DERP 监听端口>
	 CanPort80: false
	 InsecureForTests: <如果使用IP自签证书则为 true>
	 CertName: <仅当使用IP自签模式添加该字段,启动后将当前目录certs/certname.txt中内容复制到该字段>
```

更多信息请参阅 [Tailscale DERP 服务器文档](https://tailscale.com/kb/1118/custom-derp-servers/)。

## 其他注意事项及说明
1. 由于tailscaled会默认修改UDP read/write buffer,这需要CAP_NAT_ADMIN 权限并导致宿主机网络配置变更,docker-compose文件默认注释该配置,如果不介意该配置修改可以添加回该配置再启动 **[如果不修改的话启动中会提示error,但是不影响启动仅影响吞吐量]**
2. 使用自签证书情况下,derp会在中继请求到来时检查tailscale.sock,如果该请求的node key不在记录[即请求者不是当前tailscale client所处虚拟网络中的一员],则拒绝中继,自签仅影响传输过程中TLS加密部分验证校验
3. DERP服务器同时还承载了STUN功能,STUN功能可以理解为协商器,会记录所有连接设备在公网角度来看的访问IP地址,当有设备尝试相互直连的时候,STUN节点就会用于向双方分发对方的公网访问地址然后相互尝试连接,因此如果一个tailscale网络中不存在拥有IPV6地址的开启stun功能的derp节点,那么该网络中所有设备将无法进行任何ipv6直连尝试[表现在tailscale netcheck中ipv6地址永远为no],IPV4同理
4. 如配置中所写,用户可以将DERP节点配置为纯STUN协商节点/纯DERP中继节点
   
   - 纯STUN协商节点: stunonly配置为true
   - 纯DERP节点: stunport配置为-1