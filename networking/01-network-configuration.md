# Lab 01 — Network Interfaces and IP Configuration (nmcli)

**Estimated time:** 25–35 min · **Prerequisite:** `setup` done (two adapters: NAT + host-only).
**Related:** the IP you set here is used by the SSH lab and the firewall lab.

## 1. Objective

See how networking is configured on Fedora: which interfaces exist, how NetworkManager
profiles ("connections") are attached to them, how to set a static IP and how to go back to
DHCP — and why a change made with `ip` disappears while a change made with `nmcli` survives.

## 2. Environment

- Fedora Workstation VM, interfaces `enp0s3` (NAT, internet) and `enp0s8` (host-only).
- My VM's host-only connection name: `<fill in: usually "Wired connection 2">`.

> Do this lab **in the VirtualBox window**, not over SSH: changing the IP of the
> interface you are connected through kills your session. Take a snapshot first.

## 3. What I needed to do

1. List the interfaces and the NetworkManager connections.
2. Read the settings of one connection.
3. Set a static IP on the host-only interface and verify it.
4. Go back to DHCP.
5. Compare with the temporary `ip` command.
6. Set the hostname.

## 4. Commands used

### Step 1 — discovery

**Run this on Fedora**

```bash
ip -brief link               # interfaces and their link state (UP/DOWN)
ip -brief addr               # + the IP addresses
nmcli device status          # device → type → state → which connection is using it
nmcli connection show        # the saved profiles (the thing NetworkManager really manages)
```

`nmcli connection show` is the list that matters. An interface can be UP without having a
profile (then it has no IP from NetworkManager), and a profile can exist without being
active.

**Example output — your result may differ**

```text
$ nmcli device status
DEVICE  TYPE      STATE         CONNECTION
enp0s3  ethernet  connected     Wired connection 1
enp0s8  ethernet  connected     Wired connection 2
lo      loopback  connected     lo
```

### Step 2 — read a profile

**Run this on Fedora**

```bash
CON="Wired connection 2"                              # <-- use the name of YOUR host-only profile

nmcli connection show "$CON"                          # everything NetworkManager knows
nmcli -g ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns connection show "$CON"
nmcli -g connection.interface-name,connection.autoconnect connection show "$CON"
```

The profiles are stored as plain files:

```bash
sudo ls -l /etc/NetworkManager/system-connections/
sudo cat "/etc/NetworkManager/system-connections/Wired connection 2.nmconnection"
```

I keep the file in mind but I edit the profile with `nmcli`, not with an editor:
NetworkManager would not see my edit until the file was reloaded.

### Step 3 — a static IP on the host-only interface

Why: with a fixed address the host always knows where the VM is, and the firewall tests
always use the same IP. I picked `.50` because VirtualBox's host-only DHCP hands out
addresses from `.100` up, so there is no clash.

**Run this on Fedora (VirtualBox window)**

```bash
sudo nmcli connection modify "$CON" \
  ipv4.method manual \
  ipv4.addresses 192.168.56.50/24
  # no gateway here on purpose: the DEFAULT route must stay on the NAT interface

sudo nmcli connection up "$CON"        # apply it
ip -brief addr show enp0s8
nmcli -g ipv4.method,ipv4.addresses connection show "$CON"
```

Checks:

```bash
ip route show default     # the default route must still go through enp0s3 (NAT)
ping -c 2 192.168.56.1    # VirtualBox host-only network adapter on the host side
```

Now the host can reach the VM at `192.168.56.50` — that is the address I use from now on in
the SSH and firewall labs.

### Step 4 — back to DHCP

**Run this on Fedora**

```bash
sudo nmcli connection modify "$CON" ipv4.method auto ipv4.addresses ""
sudo nmcli connection up "$CON"
ip -brief addr show enp0s8       # VirtualBox DHCP gives it an address again (usually .10x)
```

I left the VM on DHCP in the end (so the labs also work after a reboot), and noted the
address in the table above.

### Step 5 — the temporary way (`ip`) for comparison

**Run this on Fedora**

```bash
sudo ip addr add 192.168.56.77/24 dev enp0s8
ip -brief addr show enp0s8        # the extra address is there
ping -c 1 192.168.56.1            # works

sudo ip addr del 192.168.56.77/24 dev enp0s8
```

Nothing was saved anywhere: NetworkManager does not know about this address, and it is gone
after `nmcli connection up` or a reboot. `ip` = "right now, for testing"; `nmcli` =
"permanent, and it survives reboots". Both are useful, for different reasons.

### Step 6 — hostname

**Run this on Fedora**

```bash
hostnamectl                       # current static/transient hostname + OS info
sudo hostnamectl set-hostname lab-fedora
exec bash                         # or open a new terminal to see the new prompt
hostname; cat /etc/hostname
```

The hostname is handled by systemd (`systemd-hostnamed`), which writes `/etc/hostname`.
(Newer systemd also accepts `sudo hostnamectl hostname lab-fedora`.)

> Fedora history note: the old `/etc/sysconfig/network-scripts/ifcfg-*` files and the
> `network` service are gone. On current Fedora, NetworkManager (and `nmcli`) is the tool.

## 5. Expected result

- `nmcli device status` shows both interfaces `connected`.
- After Step 3: `enp0s8` has `192.168.56.50/24`, `ipv4.method` is `manual`, and the default
  route still points to the NAT interface.
- After Step 4: `ipv4.method` is `auto` and the address comes from DHCP again.
- The temporary `ip addr add` address disappears after `nmcli connection up`.
- The hostname changes and survives a reboot.

## 6. What actually happened

> _Run the steps and write 4–8 lines here: the real names of your profiles, the real DHCP
> address, and whether the host could reach `192.168.56.50`. Your own words._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `Error: unknown connection 'X'` | The profile name is not exactly what you typed | `nmcli connection show` (copy the name) |
| The change does nothing | The profile was modified but not re-activated | `nmcli connection up "$CON"`, `nmcli device reapply enp0s8` |
| Lost internet after Step 3 | A gateway was set on the host-only profile | `ip route show default`, `nmcli connection show "$CON" \| grep gateway` |
| The host cannot ping the VM | Host-only network missing/disabled, or the VM picked a different subnet | VirtualBox → Tools → Network, `ip -brief addr` |
| Two default routes | Both profiles got a gateway | `ip route`, remove the gateway from the host-only profile |
| `nmcli` says "not authorized" | Need `sudo` for profile changes | rerun with `sudo` |

## 8. Evidence to capture

- `evidence/networking/01-nmcli-static-ip.png` — `nmcli connection show "$CON"` (or the `-g`
  lines) next to `ip -brief addr` showing the static address. Before/after is even better:
  one screenshot with the manual result, one with the `auto` result
  (`01-nmcli-dhcp.png`).

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: interface vs connection
> profile — what is the difference? Why did `ip addr add` not survive? Why must the
> host-only profile have no gateway?_
