# Setup — Fedora in VirtualBox

These labs use one Fedora VM. Set it up once, then start with Lab 01.


---

## 1. What you need

| Item | Value I used | Notes |
|---|---|---|
| Host OS | `<fill in: e.g. Windows 11 / macOS>` | Anything that runs VirtualBox |
| VirtualBox | 7.x | Install from virtualbox.org |
| Guest ISO | Fedora Workstation (64-bit) | ~2 GB, from <https://fedoraproject.org/workstation/download> |
| VM RAM | 4096 MB | 2048 MB works but GNOME feels slow |
| VM CPUs | 2 | |
| VM disk | 25 GB (VDI, dynamically allocated) | |

I chose **Fedora Workstation** (GNOME) because the terminal, the file manager and
the screenshot tool are all one keystroke away. Fedora Server would also work, but
some output in the screenshots would differ (different default firewalld zone).

---

## 2. Create the VM

1. **Machine → New**
   - Name: `fedora-lab`
   - Type: Linux, Version: Fedora (64-bit)
   - Memory: 4096 MB, CPUs: 2
   - Disk: 25 GB, dynamically allocated VDI
2. **Settings → Network** — this is the important part for the labs:

| Adapter | Attached to | Why |
|---|---|---|
| Adapter 1 | **NAT** | Internet access for `dnf` and updates |
| Adapter 2 | **Host-only Adapter** (`vboxnet0`) | Lets the *host* reach the VM: SSH tests and firewall tests from outside |

   Notes:
   - If no host-only network exists: **Tools → Network → Create** (this creates `vboxnet0`,
     usually `192.168.56.1/24` on the host side, with DHCP enabled).
   - With those two adapters the VM ends up with two interfaces: `enp0s3` (NAT) and
     `enp0s8` (host-only). Your names may differ — always check with `ip -brief link`.
   - Only NAT (no host-only) is not enough: several labs need to test "from the host
     machine to the VM" (SSH, firewall rules). See the NAT alternative in Lab 04 if you
     really cannot add a second adapter.

3. **Settings → System → Processor**: enable VT-x/AMD-V (usually already on).

## 3. Install Fedora

1. Attach the ISO to the virtual optical drive and boot.
2. Start the installer (Install to Hard Drive).
3. Installation destination: **Automatic partitioning** on the virtual disk.
4. Create your user (e.g. `student`) and **tick "Make this user administrator"** — that
   adds the user to the `wheel` group, which is how sudo works on Fedora.
5. Reboot into GNOME, run the first-boot wizard, skip third-party repos.

> Warning: this VM is where you will practice. It is throwaway and has no important data —
> that is exactly why we can break things in the troubleshooting labs.

## 4. First commands after install

**Run this on the Fedora VM**

```bash
# 1. update the system (do this once, it takes a while)
sudo dnf upgrade --refresh -y

# 2. tools used by the labs (dig, traceroute, nc)
sudo dnf install -y bind-utils traceroute nmap-ncat

# 3. check the two network interfaces
ip -brief addr

# 4. check the hostname and the firewall zone we start with
hostnamectl
sudo firewall-cmd --get-default-zone
```

Expected: `enp0s3` has an IP from the NAT network (usually `10.0.2.15/24`) and
`enp0s8` has an IP from the host-only network (usually `192.168.56.10x/24`).

**Example output — your result may differ**

```text
$ ip -brief addr
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp0s3           UP             10.0.2.15/24
enp0s8           UP             192.168.56.101/24
```

### Check that the host can reach the VM

Open a terminal **on the host machine** and ping the host-only IP of the VM:

```bash
ping 192.168.56.101        # Linux/macOS host
ping -n 4 192.168.56.101   # Windows host
```

If this fails, VirtualBox's host-only DHCP did not give the VM an address (or gave a
different one). Lab 01 fixes that by setting a static address on the host-only adapter.

## 5. Take a snapshot (do this before every lab that breaks something)

**VirtualBox → Snapshots → Take Snapshot**, name it `clean-install`.

Rules I follow:
- Snapshot before the troubleshooting labs (`linux/05`, `networking/05`) and before
  changing network settings.
- Snapshots are not backups and they eat disk space. I keep 2–3 and delete old ones.

## 6. Optional but nice

- Guest additions for better screen resolution and clipboard sharing:
  `sudo dnf install virtualbox-guest-additions` then reboot. If the package is not
  available on your Fedora version, skip it — none of the labs needs it.
- Screenshots in GNOME: press **Print Screen** (saves to `~/Pictures/Screenshots`).
- The repo can live inside the VM (`git clone`) so that screenshots and files are in the
  same place. See `evidence/README.md` for how to move host-side screenshots into the VM.

---

## Fedora notes used by the labs

- **firewalld on Workstation is not strict.** The default zone `FedoraWorkstation` opens
  ports 1025–65535. Lab 04 shows this and switches the VM to the `public` zone so that
  firewall tests mean something.
- **DNS is not in `/etc/resolv.conf`.** It is a symlink to the systemd-resolved stub
  (`127.0.0.53`). The real per-connection DNS settings live in NetworkManager and are
  shown with `resolvectl status`. Lab 03 covers this.
- **SELinux is enforcing by default.** It can block a service that "should" work. The labs
  stay on default ports to avoid this, but Lab 05 shows where to look if it happens.
- **`sshd` is the service name**, not `ssh` (`openssh-server` package).
