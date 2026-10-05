# Lab 04 — firewalld: Zones, Ports and Services

**Estimated time:** 40–50 min · **Prerequisite:** Lab 02 (`httpd` running), `setup` done
(host can reach the VM through the host-only adapter).
**Related:** `networking/05` Scenario B is the same kind of problem, but found the other way
around (starting from the client).

> Take a snapshot before this lab. Worst case you can always fix things again, but a
> snapshot saves 10 minutes.

## 1. Objective

Understand how firewalld decides what is allowed (zones, services, ports), discover how open
the Fedora Workstation default really is, then open a port for one service and prove — from
another machine — that the rule is what makes the difference.

## 2. Environment

| Piece | Value in my VM |
|---|---|
| Firewall | `firewalld` (active on Fedora by default) |
| Default zone (fresh Workstation install) | `FedoraWorkstation` |
| Zone I use for the tests after Step 2 | `public` |
| Interfaces | `enp0s3` (NAT), `enp0s8` (host-only, the one the host reaches) |
| Test service | `httpd` on port 80 (installed in Lab 02) |
| Test client | the **host machine** (there is a firewall on the VM only) |

## 3. What I needed to do

1. Inspect the firewall: is it running, which zone is active, what is allowed.
2. Find out why the default Workstation zone makes firewall tests meaningless, and change to
   a stricter zone the right way (per interface, through NetworkManager).
3. Test a port from the host: blocked before any rule, allowed after a rule.
4. See the difference between a runtime rule and a permanent rule.
5. Understand what a firewalld "service" (like `http`) actually is.
6. Clean up so the VM is left in a known state.

## 4. Commands used

### Step 1 — the firewall as it comes

**Run this on Fedora**

```bash
systemctl status firewalld --no-pager
sudo firewall-cmd --state                 # running / not running
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all              # everything in the active zone
sudo firewall-cmd --list-services
sudo firewall-cmd --zone=public --get-target
```

Reading `--get-active-zones`: each zone is followed by the interfaces that are in it. That is
the part people forget — a rule only matters for the interface(s) in the zone you changed.

### Step 2 — the Workstation surprise

**Run this on Fedora**

```bash
sudo firewall-cmd --info-zone=FedoraWorkstation | head -20
sudo cat /usr/lib/firewalld/zones/FedoraWorkstation.xml
```

**Example output — your result may differ**

```text
FedoraWorkstation (active)
  target: default
  interfaces: enp0s3 enp0s8
  services: dhcpv6-client mdns samba-client ssh
  ports: 1025-65535/udp 1025-65535/tcp
  ...
```

Ports `1025-65535` are open to everyone in this zone. It is a desktop decision (so that
unknown desktop apps can receive traffic without the user fighting the firewall), and it
means: on a fresh Workstation install, a test on port 8080 "works" even with no rule at all.
Any firewall demo done in this zone proves nothing.

Two ways to deal with it:

- **A: remove the range from the Workstation zone** —
  `sudo firewall-cmd --permanent --zone=FedoraWorkstation --remove-port=1025-65535/tcp --remove-port=1025-65535/udp` then `--reload`.
- **B (what I did): give the interfaces the `public` zone**, which allows only ssh,
  dhcpv6-client and mdns. `public` is the normal zone for a machine that should not accept
  random incoming connections.

### Step 3 — move both interfaces to `public`

The zone of an interface usually comes from the NetworkManager connection, so that is where
I change it (this is what makes it survive reboots):

**Run this on Fedora**

```bash
# check where each connection currently stands
nmcli -g NAME,connection.zone connection show
nmcli -g GENERAL.ZONE device show            # the zone really in force per device (empty = default zone)

NAT="Wired connection 1"        # <-- your NAT profile
HO="Wired connection 2"         # <-- your host-only profile

sudo nmcli connection modify "$NAT" connection.zone public
sudo nmcli connection modify "$HO"  connection.zone public

sudo nmcli connection up "$NAT"
sudo nmcli connection up "$HO"               # this is the interface the host uses: do it from the console

sudo firewall-cmd --get-active-zones
sudo firewall-cmd --list-all
sudo nmcli -g GENERAL.ZONE device show
```

`--get-active-zones` must now show both interfaces under `public`, and `--list-all` must show
`ports:` empty. That is my baseline for the rest of the lab.

If I want the same for interfaces that are not managed by a connection:
`sudo firewall-cmd --permanent --zone=public --change-interface=enp0s8` + `--reload`.
I used the NetworkManager way because that is where Fedora keeps it.

### Step 4 — prove port 80 is closed to the outside

Make sure the web server is running first:

**Run this on Fedora**

```bash
sudo systemctl start httpd
curl -I http://localhost                     # works — from the machine itself
sudo ss -tlnp | grep :80                     # the listener is there
sudo firewall-cmd --query-service=http       # -> no
```

Now test **from the host machine** (the VM's address: the host-only IP, e.g. `192.168.56.101`):

- Windows (PowerShell):

  ```powershell
  Test-NetConnection -ComputerName 192.168.56.101 -Port 80
  curl.exe -I --max-time 5 http://192.168.56.101/
  ```

- Linux / macOS host:

  ```bash
  nc -vz -w 3 192.168.56.101 80     # on some older macOS nc versions use -G 3 instead of -w 3
  curl -I --max-time 5 http://192.168.56.101/
  ```

Expected: the test **fails** — the service is healthy and listening, but no rule allows the
traffic in.

What the failure looks like depends on the zone target: with `target: default` firewalld
usually answers with a rejection (fast failure), with a drop-style target the client waits
and reports a timeout. **Write down what you actually got** — and note why the message alone
could not tell me the difference between "no listener" and "blocked by firewall": the only
way to know is to check the listener (`ss`) and the firewall (`--query-service`) on the VM.

### Step 5 — runtime rule vs permanent rule (the important part)

**Run this on Fedora**

```bash
# 1) runtime only (no --permanent): allowed until the next reload/reboot
sudo firewall-cmd --add-service=http
sudo firewall-cmd --list-services            # http is there now
```

Test from the host again → **it works**. Now:

```bash
sudo firewall-cmd --reload                   # reload drops all runtime rules
sudo firewall-cmd --list-services            # http is gone
```

Test from the host again → **fails**. Same commands, opposite result, because the first rule
was never saved.

```bash
# 2) now permanently, then reload so it takes effect
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
```

Test from the host → works again, and it will still be there after a reboot.

`sudo firewall-cmd --runtime-to-permanent` is the shortcut when I experimented with several
runtime rules and want to keep the ones that work.

### Step 6 — what is an `http` "service"?

**Run this on Fedora**

```bash
sudo firewall-cmd --info-service=http
sudo cat /usr/lib/firewalld/services/http.xml
sudo firewall-cmd --get-services | tr ' ' '\n' | grep -i '^http'
```

**Example output — your result may differ**

```text
$ sudo firewall-cmd --info-service=http
http
  ports: 80/tcp
  protocols:
  source-ports:
  modules:
  destination:
  includes:
```

A firewalld "service" is just a named preset with ports/protocols inside. `--add-service=http`
and `--add-port=80/tcp` end up doing the same thing for port 80 — but the service name is
clearer to read, and for a non-standard port (say 8080) I have to write the port explicitly,
because no service name exists for random ports.

Where permanent rules live:

```bash
sudo cat /etc/firewalld/zones/public.xml     # written when I used --permanent
ls -l /etc/firewalld/zones/
```

### Step 7 — optional: allow only one source address

**Run this on Fedora**

```bash
# only the host machine (192.168.56.1 = VirtualBox host-only adapter) may reach port 80
sudo firewall-cmd --permanent --remove-service=http
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.56.1" service name="http" accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-rich-rules
```

Test from the host → works. A rich rule allows conditions, not only "open for the world".
Note that a rich rule is more specific than the zone's service list, so it survives alongside
it.

### Step 8 — clean up

**Run this on Fedora**

```bash
sudo firewall-cmd --permanent --remove-service=http
sudo firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="192.168.56.1" service name="http" accept'
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
sudo systemctl stop httpd        # optional: I keep httpd installed but not running all the time
```

Final state I leave behind: `public` zone on both interfaces, `ssh` + `dhcpv6-client` allowed
(so SSH from the host keeps working), no extra ports, no rich rules.

## 5. Expected result

- `--get-active-zones` shows `public` with both interfaces, and `--list-all` has empty
  `ports:`.
- Before any rule: port 80 test from the host **fails** while `curl` on the VM works.
- Runtime rule → test works; after `--reload` → fails again; permanent rule → works and
  survives a reload.
- `/etc/firewalld/zones/public.xml` contains the permanent rule.
- Cleanup: `--list-all` shows no extra services/ports/rich rules.

## 6. What actually happened

> _Run the steps and write 5–10 lines here: what the Workstation zone showed, what the host
> test printed when the port was blocked, and what it printed after the rule (paste the real
> lines). This is the most important "actually happened" in the networking labs._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| Port 8080 test "works" although no rule exists | The interface is still in the `FedoraWorkstation` zone | `firewall-cmd --get-active-zones`, `--info-zone=FedoraWorkstation` |
| My rule does nothing | It was added to another zone, or only at runtime and got reloaded away | `firewall-cmd --get-active-zones`, `--list-all`, `--list-all-zones \| grep -A2 http` |
| The host cannot reach the VM at all — even after the rule | Wrong IP (DHCP changed it), wrong interface, or VirtualBox host-only network is not attached | `ip -brief addr` on the VM, host `ipconfig`/`ip addr`, VirtualBox settings |
| `firewall-cmd` says "FirewallD is not running" | The service is stopped | `sudo systemctl enable --now firewalld` |
| SSH from the host stopped working after the zone change | `ssh` is not allowed in the zone you moved to | fix it from the VirtualBox console: `sudo firewall-cmd --zone=public --add-service=ssh` |
| `--permanent` change has no effect | `--reload` was not run | `sudo firewall-cmd --reload` |
| Rich rule rejected | Typo in the rule text | `sudo firewall-cmd --permanent --add-rich-rule='...'` prints the error; `--check-config` |

## 8. Evidence to capture

- `evidence/networking/04-zone-rules.png` — `--get-active-zones` + `--list-all` + the
  `FedoraWorkstation` XML (or `--info-zone`) that shows `1025-65535/tcp` — this documents
  *why* the zone was changed.
- `evidence/networking/04-host-test.png` — **from the host**: the failed test before the rule
  and the successful test after it, next to the `--list-services` output on the VM. One
  image with both windows, if you can, or `04-host-test-1.png` / `-2.png`.

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: What is a zone in one
> sentence? Why is `--reload` needed after `--permanent`? Why did `curl localhost` keep
> working while the host could not connect? What would I check first if a colleague said
> "the service is up but nobody can reach it"?_
