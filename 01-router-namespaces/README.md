# Linux Network Namespace Router Lab

## Overview
This lab contains an automated [Bash script](./lab_router.sh) that builds a routing and firewall infrastructure from scratch using native Linux capabilities. It demonstrates network namespaces (`ip netns`), virtual Ethernet cables (`veth`), IP forwarding, and `iptables` for firewall rules and NAT, without the overhead of virtual machines.

## Architecture
The script provisions three isolated network namespaces and connects them via `veth` pairs. The central namespace acts as a router with NAT enabled.

```text
+----------------+                +------------------+                +----------------+
|   client_ns    |                |    router_ns     |                |   server_ns    |
| 192.168.10.2/24|                |                  |                | 192.168.20.2/24|
| (veth-client)  +----------------+ (veth-rt-client) |                | (veth-server)  |
|                |     veth       | 192.168.10.1/24  |                |                |
+----------------+     pair       |                  |                +----------------+
                                  |                  |
                                  | 192.168.20.1/24  |     veth       
                                  | (veth-rt-server) +----------------+
                                  +------------------+     pair

```

## Prerequisites

* A Linux distribution
* Root (`sudo`) privileges
* `iproute2`, `iptables`, `curl`, and `python3`
* *(Optional)* `tcpdump` or `wireshark` for packet analysis

## Quick Start

From this directory, execute the deployment script. It automatically cleans up any previous state:

```bash
sudo ./lab_router.sh
```

The script creates `client_ns`, `router_ns`, and `server_ns`, then configures their interfaces, routes, IP forwarding, firewall, and NAT rules.


## Validation & Testing

Run the following tests after deploying the lab. Commands that start a process should be run in a separate terminal from the commands that test it.

### 1. Test routing and TCP connectivity

Start a temporary HTTP server in `server_ns`:

```bash
sudo ip netns exec server_ns python3 -m http.server 8080
```

In another terminal, fetch the page from `client_ns`:

```bash
sudo ip netns exec client_ns curl --connect-timeout 2 http://192.168.20.2:8080
```

**Expected result:** The HTML directory listing is returned, confirming end-to-end routing.

### 2. Test firewall rules (ICMP block)

Ping the server from the client:

```bash
sudo ip netns exec client_ns ping -c 3 192.168.20.2
```

**Expected result:** 100% packet loss. The `iptables` `FORWARD` chain rule drops transit ICMP traffic.

### 3. Verify NAT (masquerade)

Capture traffic on the server's interface to verify that the source IP has been rewritten by the router:

```bash
sudo ip netns exec server_ns tcpdump -i veth-server -n
```

While the capture is running, repeat the `curl` command from the client. The capture should show the request originating from the router's interface (`192.168.20.1`) instead of the client's address (`192.168.10.2`), validating the NAT `MASQUERADE` rule.

Stop the HTTP server and the packet capture with `Ctrl+C` when the tests are complete.
