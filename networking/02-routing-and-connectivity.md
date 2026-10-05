# Networking Lab N2 — Routing and Connectivity Testing

**Estimated time:** 25–35 min · **Prerequisite:** `setup` (packages `traceroute`,
`nmap-ncat` installed), Networking Lab N1 not required.

## 1. Objective

Understand what a default route is, how the kernel picks an interface and a source address
for a packet, and how to test connectivity layer by layer (link → IP → route → port). Then
break the default route on purpose and repair it.

## 2. Environment

- Fedora Workstation VM. Gateway of the NAT network: `10.0.2.2` (VirtualBox NAT gateway).
  The VM's own gateway is different from the host machine's gateway — do not mix them up.

## 3. What I needed to do

1. Read the routing table and the ARP (neighbour) table.
2. Test reachability at IP level (ping, tracepath) and at port level (`nc`).
3. Test HTTP with `curl` and read the timing.
4. Delete the default route, observe what breaks, repair it.

## 4. Commands used

### Step 1 — the routing table

**Run this on Fedora**

```bash
ip route
ip route show default
ip route get 8.8.8.8      # which interface + source IP a packet to 8.8.8.8 would use
ip route get 192.168.56.1 # and for a host-only destination
```

**Illustrative output — exact values differ per VM**

```text
$ ip route
default via 10.0.2.2 dev enp0s3 proto dhcp src 10.0.2.15 metric 100
10.0.2.0/24 dev enp0s3 proto kernel scope link src 10.0.2.15 metric 100
192.168.56.0/24 dev enp0s8 proto kernel scope link src 192.168.56.101
```

How I read it: destinations on `10.0.2.0/24` and `192.168.56.0/24` are directly attached
(`scope link`); everything else goes to `default via 10.0.2.2`. `ip route get` answers the
question "for this destination, which route wins and which source address is used?" — that
is the single most useful routing command for troubleshooting.

### Step 2 — the neighbour (ARP) table

**Run this on Fedora**

```bash
ping -c 2 10.0.2.2        # make the kernel resolve the gateway's MAC address first
ip neigh                  # IP → MAC (and the state: REACHABLE / STALE / FAILED)
```

On the same LAN, addresses are resolved to MAC addresses. A line in `FAILED` state means
the machine does not answer ARP at all — a much more basic problem than routing.

### Step 3 — reachability, step by step

**Run this on Fedora**

```bash
# 1. my own loopback (is the stack alive?)
ping -c 2 127.0.0.1

# 2. the gateway (is the local network alive?)
ping -c 2 10.0.2.2

# 3. an internet IP (does routing + NAT work?)
ping -c 3 1.1.1.1

# 4. the path it takes
tracepath fedoraproject.org        # no root needed; mtr is a nicer alternative if installed
```

Some servers and networks block ICMP ping but still serve web traffic — a failed ping is a
hint, not a verdict. That is why the next step tests a real application.

### Step 4 — HTTP and ports

**Run this on Fedora**

```bash
curl -I --max-time 10 https://fedoraproject.org          # headers only
curl -s -o /dev/null -w 'code=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s total=%{time_total}s\n' \
     https://fedoraproject.org

nc -zv 1.1.1.1 53          # is the TCP port open? (-z = just check, -v = tell me)
nc -zv 10.0.2.2 22         # something that very likely is NOT open
ss -tuln                   # everything listening on this VM (TCP+UDP, no process names)
```

The timing breakdown from `curl -w` is a mini-troubleshooting tool: if `dns` is huge, DNS is
slow; if `connect` is huge, the network or a firewall is delaying the handshake.

### Step 5 — break the default route (and fix it)

**Run this on Fedora**

```bash
ip route show default                       # note the gateway and the interface first
GW=$(ip route show default | awk '{print $3}')
IF=$(ip route show default | awk '{print $5}')
echo "gateway=$GW interface=$IF"

sudo ip route del default                   # cut the way out
ip route show default                       # empty
ip route get 8.8.8.8                        # -> "Network is unreachable"
ping -c 2 1.1.1.1                           # fails, and says why
ping -c 2 10.0.2.2                          # the local network still works!
curl -I --max-time 5 https://fedoraproject.org   # fails too

sudo ip route add default via "$GW" dev "$IF"    # repair
ip route show default
ping -c 2 1.1.1.1                           # works again
```

Note what did **not** break: the directly attached networks. Losing the default route only
removes the path to everything that is not local — which is exactly why "local works,
internet does not" points at the default route.

This change is temporary. NetworkManager re-adds its own default route on
`nmcli connection up`, which is the correct behaviour for a laptop that changes networks.

### Optional — a persistent route

**Run this on Fedora**

```bash
CON="Wired connection 1"                  # NAT profile
sudo nmcli connection modify "$CON" +ipv4.routes "10.10.10.0/24 $GW"
nmcli -g ipv4.routes connection show "$CON"
ip route | grep 10.10.10.0
sudo nmcli connection modify "$CON" -ipv4.routes "10.10.10.0/24 $GW"   # remove it again
```

`+` adds an entry, `-` removes it. This is how a permanent extra route is added on Fedora.

## 5. Expected result

- `ip route show default` shows one default route via the NAT interface.
- `ip route get 8.8.8.8` names `enp0s3` and the VM's NAT address as source.
- `ping 1.1.1.1`, `tracepath`, `curl -I` all work; `nc -zv` shows one open port and one
  closed/unreachable port with a clear message each.
- After `ip route del default`: internet fails with "Network is unreachable", local network
  still answers, and the route comes back with `ip route add`.

## 6. What actually happened

I read the routing table with `ip route` and `ip route show default`. The default route went
through the NAT interface `enp0s3` and the two attached networks were `scope link`. `ip route
get 8.8.8.8` showed which interface and source address a packet to the internet would use, and
`ip route get 192.168.56.1` showed the direct route on the host-only interface. After
`ping -c 2 10.0.2.2`, `ip neigh` listed the gateway with its MAC address.

I tested the path in layers: ping to `127.0.0.1`, to the gateway `10.0.2.2` and to `1.1.1.1`,
then `tracepath fedoraproject.org`. For the application layer I used `curl -I` and the `curl
-w` timing line (name lookup, connect, total), and `nc -zv` to one port that was open
(`1.1.1.1` port 53) and one that was not (`10.0.2.2` port 22). `ss -tuln` showed what the VM
itself was listening on.

Then I removed the default route with `sudo ip route del default`. `ip route show default` was
empty, `ip route get 8.8.8.8` reported `Network is unreachable`, and ping to `1.1.1.1` and
`curl` failed, but ping to the gateway `10.0.2.2` still worked. I restored the route with
`ip route add default via "$GW" dev "$IF"` using the gateway and interface I saved before, and
ping to `1.1.1.1` worked again. I did not run the optional persistent route test.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `Network is unreachable` | No route for that destination (often no default route) | `ip route`, `ip route get <IP>` |
| Ping fails but `curl https://...` works | ICMP blocked somewhere on the path | `curl -I`, `nc -zv host 443` |
| `Name or service not known` | DNS, not routing | N3 / N5 (Scenario A) |
| `tracepath` stops at the first hop | That hop does not send the ICMP replies tracepath uses (very common with NAT/ISP) | try `tracepath -n 8.8.8.8`, or accept it and use `curl` timing |
| `nc: connect ... Connection refused` | The host is reachable, nothing listens on that port | `ss -tln` on the target, `firewall-cmd --list-all` |
| `nc` hangs with no message | Dropped packets (firewall) instead of a refusal | `--timeout`, then check firewalls on both sides |
| I deleted the default route and now nothing works | You did not restore it | `sudo ip route add default via <GW> dev <IF>`, or reboot the VM |

## 8. Evidence

No screenshot is part of this lab. The evidence is the command flow in section 4 and
the results written down in section 6.

## 9. What I learned

The default route is the entry the kernel uses for every destination that is not in a directly
attached network. Without it the machine can still talk to its local networks (they have their
own `scope link` routes) but has no way out, which is exactly what happened: gateway ping
worked, internet ping failed with `Network is unreachable`. So "local works, internet does
not" is a good hint to check `ip route`.

`ip route` shows the whole table, while `ip route get <IP>` answers the more useful question for
one destination: which route wins and which source address is used. Testing in layers (loopback,
gateway, internet IP, then an application with `curl`) tells me where the path stops. A failed
ping is only a hint because ICMP can be blocked while web traffic works.

For port checks I learned the difference between "refused" (the host answered and nothing
listens) and "hung" (packets were probably dropped, for example by a firewall). Changes made with
`ip route` are temporary; a permanent route belongs in the NetworkManager profile.
