# Networking Lab N5 — Network Troubleshooting (2 Scenarios)

**Estimated time:** 40–50 min · **Prerequisite:** `networking/03` (DNS) and `networking/04`
(firewall) done — the faults below are created with the same tools, so I need to know them
first. Snapshot recommended.

## 1. Objective

Practise a troubleshooting **order** instead of guessing, on two problems that look similar
from the user's side ("it does not work") but live on completely different layers:
a name resolution problem and a firewall problem. For each one I write down
symptom → investigation → finding → fix → verification.

## 2. Environment

- Fedora VM in the `public` firewalld zone, `sshd` running (Linux Lab 04), NAT + host-only.
- The two faults (a wrong DNS server, and a removed firewall rule) are created by me at the
  start of each scenario.

## 3. What I needed to do

1. Use a fixed order of checks for "the network does not work".
2. **Scenario A:** break DNS, find out where the wrong setting is, fix it.
3. **Scenario B:** a service that works locally but is unreachable from the host — find out
   why, and fix it.

---

## 4. Commands used

### Part 0 — the order I check things in (before touching anything)

| # | Question | Command | If it fails |
|---|---|---|---|
| 1 | Is the interface up with an IP? | `ip -brief addr` | link/IP problem (N1) |
| 2 | Is there a route out? | `ip route`, `ip route get 8.8.8.8` | routing problem (N2) |
| 3 | Does an IP address answer? | `ping -c 2 1.1.1.1` | link/route/NAT |
| 4 | Does a **name** resolve? | `getent hosts fedoraproject.org` | DNS problem (this lab / N3) |
| 5 | Does the application answer? | `curl -I https://...`, `nc -zv host port` | port/service/firewall |
| 6 | Is the service listening there? | `ss -tlnp` (on the target) | service problem (Linux Lab 02/05) |
| 7 | Is anything blocking it? | `sudo firewall-cmd --list-all` | firewall (N4) |
| 8 | What do the logs say? | `journalctl -u <service> -n 30` | the error is usually written there |

`ping` answers question 3, not question 4 or 5. Most of the time I lose time because I test
the wrong layer.

---

### Scenario A — "the internet is down" (IP works, names do not)

**Step 1 — create the fault**

**Run this on Fedora**

```bash
NAT="Wired connection 1"        # NAT profile (the one with the default route)
sudo nmcli connection modify "$NAT" ipv4.ignore-auto-dns yes ipv4.dns 192.0.2.1
sudo nmcli connection up "$NAT"
```

`192.0.2.1` is an address from the reserved documentation range: it is guaranteed not to
answer, which makes it a perfect "dead" DNS server.

**Step 2 — the symptom**

**Run this on Fedora**

```bash
ping -c 2 1.1.1.1                  # works → the network itself is fine
ping -c 2 fedoraproject.org        # ping: fedoraproject.org: Name or service not known
curl -I --max-time 5 https://fedoraproject.org   # curl: (6) Could not resolve host
```

**Step 3 — investigate (in this order)**

**Run this on Fedora**

```bash
cat /etc/resolv.conf                # only 127.0.0.53 — looks "healthy", and that is the trap
resolvectl status | sed -n '1,25p'  # THE real state: which DNS server per link
resolvectl query fedoraproject.org  # the resolver's own answer (times out here)

# is the configured server even reachable?
ping -c 2 192.0.2.1                 # 100% packet loss

# isolate: ask a public server directly, ignoring my configuration
dig +short +time=3 +tries=1 @1.1.1.1 fedoraproject.org    # -> answers! network + DNS protocol OK
dig +short +time=3 +tries=1 fedoraproject.org              # -> no answer (it asks 127.0.0.53 → 192.0.2.1)
```

**Finding:** the network is fine (`ping 1.1.1.1` and `dig @1.1.1.1` both work), but the
resolver configuration of the NAT connection points at a DNS server that does not answer.
Restarting `systemd-resolved` would not have helped — the bad server is not a service
problem, it comes from the connection profile.

**Step 4 — fix and verify**

**Run this on Fedora**

```bash
sudo nmcli connection modify "$NAT" ipv4.ignore-auto-dns no ipv4.dns ""
sudo nmcli connection up "$NAT"

resolvectl status | sed -n '1,20p'      # the correct DNS server is back
resolvectl query fedoraproject.org      # resolves
ping -c 2 fedoraproject.org             # works
curl -I --max-time 10 https://fedoraproject.org   # HTTP status line
```

**What I must be able to explain:** why `/etc/resolv.conf` looked normal the whole time, and
why `dig @1.1.1.1` was the command that split the problem into "network" vs "DNS config".

---

### Scenario B — "the server is up but I cannot connect to it" (firewall)

**Step 1 — create the fault**

Create it from the VirtualBox console (not over SSH, so you can watch), and first make sure
`ssh` is allowed, otherwise you would be breaking something that is already broken:

**Run this on Fedora**

```bash
sudo firewall-cmd --query-service=ssh           # -> yes (baseline)
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --reload
sudo firewall-cmd --list-services               # ssh is gone
```

**Step 2 — the symptom (from the client side!)**

**Run this on the host machine**

```bash
ssh student@192.168.56.101        # hangs, then: ssh: connect to host ... port 22: Connection timed out
# or, quick version:
nc -vz -w 3 192.168.56.101 22     # Linux/macOS host (-G 3 instead of -w 3 on older macOS)
```

```powershell
# Windows host
Test-NetConnection -ComputerName 192.168.56.101 -Port 22
```

Record the exact message you get. A timeout (or a fast rejection) tells me *that* something
is blocking, but not *what* — remember N4: a rejected/dropped packet and "nothing
listening" can produce messages that look similar.

**Step 3 — investigate (on the VM, and from the host)**

**Run this on Fedora**

```bash
# 1. Is the service itself OK? 
systemctl status sshd --no-pager | head -5     # active (running)
sudo sshd -t                                   # config is valid: no output

# 2. Is it listening, and where?
sudo ss -tlnp | grep :22                       # LISTEN 0.0.0.0:22  (all interfaces)

# 3. Does it work locally? (loopback is not filtered by firewalld)
ssh -o ConnectTimeout=5 localhost true; echo "exit=$?"
nc -zv 127.0.0.1 22                            # succeeds

# 4. So the service is fine. What is different for traffic coming from outside?
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
sudo firewall-cmd --query-service=ssh          # -> no  <-- found it
sudo journalctl -u firewalld --since "5 min ago" --no-pager | tail -5
```

**Finding:** `sshd` is running and listening on all interfaces, and it answers on the
loopback. The only difference between "works locally" and "fails from the host" is the path
the packets take — and on that path the interface `enp0s8` sits in the `public` zone, which
no longer allows the `ssh` service. Nothing was wrong with the service; the rule that let
the traffic in was missing.

**Step 4 — fix and verify**

**Run this on Fedora**

```bash
# runtime first (test it), then make it permanent
sudo firewall-cmd --add-service=ssh
```

**Run this on the host machine**

```bash
ssh student@192.168.56.101        # a NEW connection works now
```

**Run this on Fedora**

```bash
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
sudo firewall-cmd --query-service=ssh          # yes
sudo firewall-cmd --list-all
```

Then verify once more from the host with a fresh connection (`ssh` a second time in a new
terminal), so the proof is not just the old session that was already established.

**What I must be able to explain:** why the existing SSH session kept working while new
connections failed (`firewalld` allows traffic that belongs to an already established
connection, and the connection was opened before the rule was removed), and why testing
"locally" is the first thing that tells me the service is not the problem.

---

## 5. Expected result

- Scenario A: `ping 1.1.1.1` works, `ping fedoraproject.org` fails, `resolvectl status`
  shows the wrong server, `dig @1.1.1.1` works; after the nmcli revert everything resolves
  again.
- Scenario B: from the host, SSH fails while `sshd` is active and listening; `localhost`
  works; `--query-service=ssh` says `no`; after re-adding the service, a **new** SSH
  connection succeeds.
- Both scenarios are written down in section 6 in the Symptom → Investigation → Finding →
  Fix → Verification shape.

## 6. What actually happened

I used the order of checks from Part 0 (interface and IP, route, IP ping, name resolution,
application, listener, firewall, logs) so I would not test the wrong layer.

**Scenario A: IP works but DNS does not.** I created the fault with `ipv4.ignore-auto-dns yes
ipv4.dns 192.0.2.1` on the NAT profile. Symptom: `ping -c 2 1.1.1.1` worked, but `ping
fedoraproject.org` failed with `Name or service not known` and `curl` could not resolve the
host. Checks: `cat /etc/resolv.conf` looked normal (only `127.0.0.53`), but `resolvectl status`
listed `192.0.2.1` as the DNS server, `resolvectl query` failed and `ping 192.0.2.1` got no
answer. `dig @1.1.1.1 fedoraproject.org` worked while the plain `dig` did not. Cause: the NAT
connection pointed at a DNS server that does not answer. Fix: `ipv4.ignore-auto-dns no`, an
empty `ipv4.dns`, then `nmcli connection up`. Verification: `resolvectl query`, `ping
fedoraproject.org` and `curl -I` worked again.

**Scenario B: service listening, remote access blocked.** I removed `ssh` from the `public` zone
with `--permanent --remove-service=ssh` and `--reload`. Symptom: from the host, a new
`ssh student@192.168.56.101` did not connect. Checks on the VM: `sshd` was `active (running)`,
`sshd -t` printed nothing, `ss` showed port 22 listening, the local test with `nc` on
`127.0.0.1` worked, and `--query-service=ssh` said `no`. Cause: the firewall zone no longer
allowed `ssh`; the service itself was fine. Fix: `--add-service=ssh` at runtime, a new SSH
connection from the host, then `--permanent --add-service=ssh` and `--reload`. Verification:
`--query-service=ssh` said `yes` and a fresh SSH connection from the host worked.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| Scenario A: even `ping 1.1.1.1` fails | You broke more than DNS (interface/gateway) | `ip -brief addr`, `ip route` |
| Scenario A: the fix does not come back after `nmcli con up` | `ipv4.dns` was not cleared, or the profile was not reactivated | `nmcli -g ipv4.dns,ipv4.ignore-auto-dns connection show "$NAT"` |
| Scenario A: names still cached and it looks fixed | The resolver cache still holds an old entry | `resolvectl flush-caches`, then test again |
| Scenario B: I locked myself out completely | `ssh` was removed **and** the zone changed in the same session | from the VirtualBox console, not over SSH |
| Scenario B: still no connection after the fix | Wrong IP, the interface is in a different zone, or `sshd` listens on a specific address only | `ip -brief addr`, `nmcli -g GENERAL.ZONE device show`, `sudo ss -tlnp \| grep :22` |
| Scenario B: the host shows a firewall of its own blocking it | Host-side antivirus/browser firewall blocks the VirtualBox host-only subnet | PowerShell: `Get-NetFirewallProfile` / Windows Defender Firewall settings (outside the VM, out of scope for this repo) |
| I am not sure which layer is broken | Stop guessing | Follow the 8-row table in Part 0 |

## 8. Evidence

No screenshot is part of this lab. The evidence is the command flow in section 4 and
the results written down in section 6.

## 9. What I learned

In Scenario A the key check was `dig @1.1.1.1`: it worked, so the network and the DNS
protocol were fine and only my DNS configuration was wrong. `/etc/resolv.conf` looked healthy
the whole time, because it only shows the local stub, so `resolvectl status` was the check that
showed the real server. Restarting `systemd-resolved` would have been a guess that did not fix
the cause.

In Scenario B the key check was the difference between local and remote. `sshd` was running,
listening and answering on the loopback, so the service was not the problem. The packets from
outside were stopped by the zone, and `--query-service=ssh` showed it. In both scenarios the
service or network seemed to "work", but the user could not use it, because the fault was one
layer away: DNS configuration in A, firewall rule in B.

The lesson for my own work is to follow the order from Part 0 and to verify a fix with the same
command that failed at the start. I should also use a new connection to test, because an
established session can survive a removed rule and look like a success.
