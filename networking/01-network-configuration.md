# Networking Lab N1 — Network Interfaces and IP Configuration (nmcli)

**Estimated time:** 25–35 min · **Prerequisite:** `setup` done (two adapters: NAT + host-only).
**Related:** the IP you set here is used by the SSH lab and the firewall lab.

## 1. Objective

See how networking is configured on Fedora: which interfaces exist, how NetworkManager
profiles ("connections") are attached to them, how to set a static IP and how to go back to
DHCP — and why a change made with `ip` disappears while a change made with `nmcli` survives.

## 2. Environment

- Fedora Workstation VM, interfaces `enp0s3` (NAT, internet) and `enp0s8` (host-only).
- My VM's host-only connection name: `Wired connection 2` (the name used in the commands below).

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

**Illustrative output — exact values differ per VM**

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
CON="Wired connection 2"                              # host-only profile

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

I listed the interfaces with `ip -brief link` and `ip -brief addr`, and the NetworkManager
profiles with `nmcli device status` and `nmcli connection show`. Both `enp0s3` (NAT) and
`enp0s8` (host-only) were connected, each with its own profile; the host-only profile was
`Wired connection 2`. I read its settings with `nmcli -g ... connection show` and looked at the
stored `.nmconnection` file under `/etc/NetworkManager/system-connections/`.

I set a static address on the host-only profile with `nmcli connection modify` (`ipv4.method
manual`, `ipv4.addresses 192.168.56.50/24`, no gateway) and activated it with `nmcli connection
up`. `ip -brief addr show enp0s8` then showed `192.168.56.50/24`, and `ip route show default`
still pointed to the NAT interface, as planned. I also pinged `192.168.56.1`, the host-side
host-only adapter. Then I returned the profile to DHCP with `ipv4.method auto` and verified
with `ip -brief addr` that VirtualBox DHCP had given the interface an address again.

For comparison I added `192.168.56.77/24` with `ip addr add`. It showed up in `ip -brief addr`
and the ping worked, and I removed it again with `ip addr del`. Finally I used `hostnamectl` and
`hostnamectl set-hostname lab-fedora`, and checked the result with `hostname` and
`/etc/hostname`.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `Error: unknown connection 'X'` | The profile name is not exactly what you typed | `nmcli connection show` (copy the name) |
| The change does nothing | The profile was modified but not re-activated | `nmcli connection up "$CON"`, `nmcli device reapply enp0s8` |
| Lost internet after Step 3 | A gateway was set on the host-only profile | `ip route show default`, `nmcli connection show "$CON" \| grep gateway` |
| The host cannot ping the VM | Host-only network missing/disabled, or the VM picked a different subnet | VirtualBox → Tools → Network, `ip -brief addr` |
| Two default routes | Both profiles got a gateway | `ip route`, remove the gateway from the host-only profile |
| `nmcli` says "not authorized" | Need `sudo` for profile changes | rerun with `sudo` |

## 8. Evidence

No screenshot is part of this lab. The evidence is the command flow in section 4 and
the results written down in section 6.

## 9. What I learned

An interface is the device the kernel sees (`enp0s8`). A NetworkManager connection is a saved
profile with the settings (DHCP or static, address, gateway, DNS, zone) that gets applied to a
device. `nmcli connection show` lists the profiles, and `ip addr` shows the state that is
really on the interface now. After `nmcli connection modify` the profile is changed, but the
interface only follows after `nmcli connection up`, so I verify both: the profile with `nmcli
-g` and the result with `ip`.

The `ip addr add` test showed the other difference: `ip` changes the running state only, so it
is good for a quick test but is not saved, while `nmcli` changes are kept and come back after a
reboot. I also learned why the host-only profile has no gateway: a second default route would
compete with the NAT one and could break the internet access of the VM. Do the interface
changes in the VirtualBox window, not over SSH, because a changed IP ends the session.
