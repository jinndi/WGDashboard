<p align="center">
  <img alt="WGDashboard" src="/logo.webp" width="180">
</p>
<h1 align="center">
<a href="https://github.com/donaldzou/WGDashboard">WGDashboard</a> docker image
</h1>
<h3 align="center">
Simple WireGuard VPN web control panel Docker image
</h3>
<p align="center">
<img alt="Release" src="https://img.shields.io/github/v/release/jinndi/WGDashboard">
<img alt="Code size in bytes" src="https://img.shields.io/github/languages/code-size/jinndi/WGDashboard">
<img alt="License" src="https://img.shields.io/github/license/jinndi/WGDashboard">
<img alt="Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/jinndi/WGDashboard/build.yml">
<img alt="Visitor" src="https://hitscounter.dev/api/hit?url=https%3A%2F%2Fgithub.com%2Fjinndi%2FWGDashboard&label=visitor&icon=eye&color=%230d6efd&message=&style=flat&tz=UTC">
</p>

## 🧩 Differences from the official image
- Built on a clean Alpine base image
- Clean image, no extra env variables, all settings in web panel
- Supports only two architectures: linux/amd64 and linux/arm64
- Automatic configuration of forwarding rules for WG interfaces
- Per the POSIX/Unix standard, environment variables are written in UPPERCASE
- The base paths to resource files have been fixed for operation behind a reverse proxy

## 📋 Requirements

- A host with a kernel that supports WireGuard (all modern kernels)
- To use AmneziaWG, you need to install the [kernel module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module)
- Curl and Docker installed
- You need to have a domain name or a public IP address

## 🐳 Installation

### 1. Install Docker

If you haven't installed Docker yet, install it by running

```bash
curl -sSL https://get.docker.com | sh
sudo usermod -aG docker $(whoami)
```

### 2. Download docker compose file in curren dirrectory

```bash
curl -O https://raw.githubusercontent.com/jinndi/WGDashboard/main/compose.yml
```

### 3. Fill in the environment variables using any convenient editor, for example nano

```bash
nano compose.yml
```

### 4. Setup Firewall

If you are using a firewall, you need to open the following ports:

- UDP port(s) (or range of used) of the `wgd` service in `compose.yml`

### 5. Run compose.yml

From the same directory where you uploaded and configured compose.yml

```bash
docker compose up -d
```

The panel will be available within 5 minutes after a successful launch at:
`http://<HOST>:<PORT>`

> Stop: `docker compose down`, Update: `docker compose pull`, Logs: `docker compose logs`

## ⚙️ Options

| Env                | Default                 | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------ | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TZ`               | `Europe/Amsterdam`      | Timezone. Useful for accurate logs and scheduling. Example: `Europe/Moscow`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `HOST`         | Autodetect IP           | Domain or IPv4/IPv6 for WG clients. Example: `myhost.com`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `PORT`         | `10086`                 | WEB UI port. Example: `1125`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `ALLOW_FORWARD`    | -                       | By default, all interfaces and peers are isolated from each other. You can specify comma-separated interface (configuration) names to remove these restrictions. Example: `wg0,wg1`                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `NET_IFACE`    | Autodetect                       | The default Internet-facing interface used to access the Internet, through which FORWARD rules between WG interfaces are configured. It is determined automatically, but if you want to specify a particular name, enter it here. Example: `tun0`                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
