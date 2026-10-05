# Networking Lab N3 — DNS on Fedora (systemd-resolved + NetworkManager)

**Estimated time:** 30–40 min · **Prerequisite:** `setup` (`bind-utils` installed), N1/N2
helpful.
**Related:** this is the base for Scenario A in `networking/05`.

## 1. Objective

Understand where DNS settings actually live on Fedora (it is **not** `/etc/resolv.conf`),
query DNS with `dig`, see what applications use instead of `dig`, and change the DNS server
of a connection properly with `nmcli`.

## 2. Environment

- Fedora Workstation VM. DNS is handled by `systemd-resolved` (stub listener on
  `127.0.0.53`) and the per-connection settings come from NetworkManager.

## 3. What I needed to do

1. Look at `/etc/resolv.conf` and understand why I must not edit it.
2. Read the real DNS state with `resolvectl`.
3. Query records with `dig`, including querying a specific server.
4. Compare `dig` with `getent hosts` (what applications really use).
5. Override one name with `/etc/hosts`.
6. Change the DNS servers of the connection with `nmcli`, then revert.

## 4. Commands used

### Step 1 — the file everyone edits (and should not)

**Run this on Fedora**

```bash
ls -l /etc/resolv.conf        # a symlink to /run/systemd/resolve/stub-resolv.conf
cat /etc/resolv.conf
```

**Illustrative output — exact values differ per VM**

```text
# This is /run/systemd/resolve/stub-resolv.conf managed by man:systemd-resolved(8).
# Do not edit.
nameserver 127.0.0.53
options edns0 trust-ad
search .
```

There is no real DNS server in this file, only the local stub. Writing `nameserver 8.8.8.8`
into it does nothing useful: systemd-resolved will overwrite it, and applications ask
`127.0.0.53` instead. On Fedora the setting belongs to the NetworkManager connection.

### Step 2 — the real state

**Run this on Fedora**

```bash
resolvectl status            # per-link DNS servers, DNS domains, current server
resolvectl query fedoraproject.org
resolvectl statistics | head -12
```

`resolvectl status` is the command that answers "which DNS server is this machine using
right now, and for which interface?". In my VM the NAT interface has the DNS server that
VirtualBox's NAT hands out, and the host-only interface has none.

### Step 3 — query with `dig`

**Run this on Fedora**

```bash
dig fedoraproject.org            # full answer: QUESTION, ANSWER, SERVER, query time
dig +short fedoraproject.org     # just the answer
dig MX gmail.com +short          # another record type (a domain that has MX records)
dig +noall +answer fedoraproject.org

dig @1.1.1.1 fedoraproject.org   # ask a SPECIFIC server, ignoring my configuration
dig @1.1.1.1 +short fedoraproject.org

dig doesnotexist.invalid         # -> status: NXDOMAIN (the name really does not exist)
```

Two things I check in the header: the `status` (`NOERROR`, `NXDOMAIN`, `SERVFAIL`, or a
timeout) and the `SERVER` line — by default dig asks `127.0.0.53`, the local stub.
`dig @1.1.1.1` is the classic isolation trick: if that works while the default query fails,
the network is fine and only my local resolver configuration is wrong (that is Scenario A in
N5).

Small trap: `dig` exits with status 0 even when the answer is NXDOMAIN, so its exit code is
not a good "did it work?" test in scripts. `getent hosts` does return a non-zero exit
status — which is why I used it in `scripts/network-check.sh`.

### Step 4 — `dig` vs what applications do

**Run this on Fedora**

```bash
getent hosts fedoraproject.org     # what a normal program (glibc) resolves
grep ^hosts /etc/nsswitch.conf     # the order: files (hosts), then dns
```

`dig` talks to DNS directly. Applications (browsers, `curl`, `ssh`) use the system resolver,
which follows `/etc/nsswitch.conf` and checks `/etc/hosts` first. So "dig works but the
browser says host not found" is possible, and the other way round too.

### Step 5 — `/etc/hosts` override

**Run this on Fedora**

```bash
echo "127.0.0.1 mylab.test" | sudo tee -a /etc/hosts

getent hosts mylab.test        # -> 127.0.0.1   (found in /etc/hosts)
ping -c 1 mylab.test           # pings my own machine
dig mylab.test                 # -> NXDOMAIN: dig only asks DNS, it does not read /etc/hosts

sudo sed -i '/mylab.test/d' /etc/hosts     # clean up, left the file as it was
getent hosts mylab.test                    # now it fails again
```

### Step 6 — change the DNS servers of a connection

**Run this on Fedora**

```bash
CON="Wired connection 1"      # NAT profile (the one with the gateway)

nmcli -g ipv4.dns,ipv4.ignore-auto-dns connection show "$CON"   # before: probably empty

sudo nmcli connection modify "$CON" ipv4.ignore-auto-dns yes ipv4.dns "1.1.1.1 9.9.9.9"
sudo nmcli connection up "$CON"

resolvectl status | sed -n '1,20p'
resolvectl query fedoraproject.org
dig +short fedoraproject.org

# revert to what DHCP gave me
sudo nmcli connection modify "$CON" ipv4.ignore-auto-dns no ipv4.dns ""
sudo nmcli connection up "$CON"
resolvectl status | sed -n '1,20p'
```

Tip: if I am logged in over SSH through the host-only interface, reactivating the NAT
connection is safe — it is a different interface. Reactivating the connection I am connected
through would cut my session.

Why `ipv4.ignore-auto-dns yes`: without it, the DNS servers from DHCP are still added and
mine would just be one more entry. This is the difference between "add servers" and
"replace them".

### Optional — what DNS caching gives me

**Run this on Fedora**

```bash
dig fedoraproject.org | grep -E 'Query time|SERVER'
dig fedoraproject.org | grep -E 'Query time|SERVER'   # usually faster: resolved cached it
resolvectl flush-caches                                # clear the cache and compare again
```

## 5. Expected result

- `/etc/resolv.conf` is a symlink and contains only `nameserver 127.0.0.53`.
- `resolvectl status` shows the DNS server per interface.
- `dig +short` prints addresses; `dig doesnotexist.invalid` prints `status: NXDOMAIN`.
- `dig @1.1.1.1 ...` works even if the local DNS config is wrong.
- After Step 5: `getent hosts mylab.test` works, `dig mylab.test` does not.
- After Step 6: `resolvectl status` lists `1.1.1.1 9.9.9.9` for the NAT link, and reverting
  brings back the original servers.

## 6. What actually happened

`ls -l /etc/resolv.conf` showed a symlink to the systemd-resolved stub file, and `cat` showed
only the local stub address `127.0.0.53`, so the real DNS settings are not in that file. I read
the real state with `resolvectl status` (the NAT interface had the DNS server handed out by
VirtualBox NAT and the host-only interface had none) and with `resolvectl query
fedoraproject.org`.

With `dig` I compared the full answer, `+short`, `MX` for `gmail.com` and `+noall +answer`. I
asked a specific server with `dig @1.1.1.1 fedoraproject.org` and read the `SERVER` line and
the query time in the header. `dig doesnotexist.invalid` returned `status: NXDOMAIN`.
`getent hosts fedoraproject.org` also resolved, and `grep ^hosts /etc/nsswitch.conf` showed the
lookup order.

For `/etc/hosts` I added `127.0.0.1 mylab.test`. `getent hosts mylab.test` and `ping` found
it, but `dig mylab.test` returned `NXDOMAIN`, because `dig` only asks DNS. I deleted the line
afterwards and `getent` failed again.

Last, I set `ipv4.ignore-auto-dns yes` and `ipv4.dns "1.1.1.1 9.9.9.9"` on the NAT profile,
activated it, and `resolvectl status` then listed those servers for the NAT link. Name
resolution kept working. I reverted with `ipv4.ignore-auto-dns no` and an empty `ipv4.dns`,
and `resolvectl status` showed the original server again.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `resolvectl: command not found` | `systemd-resolved` not installed (unusual on Fedora) | `rpm -q systemd-resolved`, `systemctl status systemd-resolved` |
| `Temporary failure in name resolution` | No usable DNS server, or the resolver is not reachable | `resolvectl status`, `resolvectl query <name>`, `dig @1.1.1.1 <name>` |
| `dig` times out with no answer | The server is unreachable (blocked or down) | `ping -c 2 1.1.1.1`, `dig @9.9.9.9 <name>` |
| `SERVFAIL` for every name | The resolver is reachable but cannot resolve (broken upstream/DNSSEC) | `dig +cd <name>`, then check the upstream server |
| `/etc/resolv.conf` is a normal file | Someone deleted the symlink earlier | systemd-resolved recreates it after reboot, or `systemctl restart systemd-resolved` |
| My DNS change had no effect | `ignore-auto-dns` not set, so DHCP servers are still listed | `nmcli -g ipv4.dns,ipv4.ignore-auto-dns connection show "$CON"` |
| `getent hosts` works but `dig` does not | The name is in `/etc/hosts` | `grep <name> /etc/hosts` |

## 8. Evidence

No screenshot is part of this lab. The evidence is the command flow in section 4 and
the results written down in section 6.

## 9. What I learned

DNS configuration answers "which servers does this machine ask, and for which interface?". On
Fedora that lives in the NetworkManager connection and is applied by `systemd-resolved`, and I
read it with `resolvectl status`. Hostname resolution answers "what IP does this name have?", and
it is done by the system resolver, which follows `/etc/nsswitch.conf`, checks `/etc/hosts`
first and then asks DNS. The two can disagree: `getent hosts mylab.test` worked through
`/etc/hosts`, while `dig` (DNS only) did not.

Editing `/etc/resolv.conf` is the wrong fix on Fedora, because it is only a link to the stub
at `127.0.0.53`, and systemd-resolved manages the real servers. That stub is a local resolver
that forwards my queries to the configured servers.

`dig @server` is useful to ask one specific server and ignore my local configuration. If it
works while the normal query fails, the network is fine and the local DNS configuration is the
problem. I also learned that `ipv4.ignore-auto-dns yes` replaces the DHCP servers instead of
adding to them, and that `getent hosts` is a better test than `dig` for what applications see.
