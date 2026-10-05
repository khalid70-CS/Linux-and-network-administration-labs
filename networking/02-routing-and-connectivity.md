# Lab 02 — Routing and Connectivity Testing

**Estimated time:** 25–35 min · **Prerequisite:** `setup` (packages `traceroute`,
`nmap-ncat` installed), Lab 01 not required.

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

**Example output — your result may differ**

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
CON="Wired connection 1"                  # <-- your NAT profile
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

> _Run the steps and write 4–8 lines here: your real gateway/interface, the real tracepath
> hops (how many?), and the exact error message you got after deleting the default route._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `Network is unreachable` | No route for that destination (often no default route) | `ip route`, `ip route get <IP>` |
| Ping fails but `curl https://...` works | ICMP blocked somewhere on the path | `curl -I`, `nc -zv host 443` |
| `Name or service not known` | DNS, not routing | Lab 03 / Lab 05 (Scenario A) |
| `tracepath` stops at the first hop | That hop does not send the ICMP replies tracepath uses (very common with NAT/ISP) | try `tracepath -n 8.8.8.8`, or accept it and use `curl` timing |
| `nc: connect ... Connection refused` | The host is reachable, nothing listens on that port | `ss -tln` on the target, `firewall-cmd --list-all` |
| `nc` hangs with no message | Dropped packets (firewall) instead of a refusal | `--timeout`, then check firewalls on both sides |
| I deleted the default route and now nothing works | You did not restore it | `sudo ip route add default via <GW> dev <IF>`, or reboot the VM |

## 8. Evidence to capture

- `evidence/networking/02-routes.png` — `ip route`, `ip route get 8.8.8.8`, the empty route
  after the break, and the restored route + successful ping. (If you take the screenshot in
  two parts, use `02-routes-1.png` / `02-routes-2.png`.)
- `evidence/networking/02-tracepath.png` (optional) — one `tracepath` result.

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: What exactly does the
> default route do? Why did the local network keep working when the default route was gone?
> How is `ip route get <IP>` different from `ip route`? What is the difference between a
> "refused" and a "hung" port check?_
