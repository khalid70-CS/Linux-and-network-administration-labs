# Linux & Networking Lab

A hands-on Fedora lab for Linux fundamentals, networking, SSH, and basic troubleshooting,
built as university-level practice on a single VirtualBox VM.

| | |
|---|---|
| **Project** | Linux & Networking Lab (university-level practical lab) |
| **Environment** | Windows 11 host + VirtualBox + Fedora Workstation VM |
| **Skills demonstrated** | Linux administration fundamentals, users/groups/permissions, processes and services, packages and filesystem inspection, SSH, logs and troubleshooting, NetworkManager (`nmcli`), IP configuration, routing, DNS, firewalld, network troubleshooting, basic read-only Bash checks |
| **Level** | Student lab / hands-on practice, not production experience |

## Status

All 10 labs (5 Linux, 5 networking) were completed and verified on my Fedora VM. Each lab
file contains the commands, what actually happened, and what I learned. Screenshots exist only
for the four Linux evidence items listed in `evidence/README.md`; the networking labs are
documented in their Markdown files.

## What is covered

- 5 Linux labs: users and permissions, processes and services, packages and filesystem, SSH,
  and logs/troubleshooting.
- 5 networking labs: interface configuration, routing, DNS, firewalld, and network
  troubleshooting.
- 2 read-only Bash checks for system and network state.
- 4 fault scenarios used to practise troubleshooting instead of only following setup steps.

The VM is a lab machine, not a production server. No Ansible, Terraform, containers, CI/CD,
or other automation tools are used.

## Environment

| Item | Setup |
|---|---|
| Host | Windows 11 |
| Hypervisor | VirtualBox 7.x |
| Guest | Fedora Workstation, 64-bit |
| VM | 4 GB RAM, 2 CPUs, 25 GB disk |
| Adapter 1 | NAT |
| Adapter 2 | Host-only, `192.168.56.0/24` |
| User | normal user in `wheel` |

I took snapshots before the labs that intentionally change or break the system.

## Tools

Fedora Linux, VirtualBox, Bash, systemd (`systemctl`, `journalctl`), NetworkManager (`nmcli`),
systemd-resolved (`resolvectl`), firewalld, OpenSSH, `ip`, `ss`, `ping`, `tracepath`, `dig`,
`curl`, `nc`, `dnf`, `rpm`, Git, and GitHub.

## Repository

```text
linux-networking-lab/
├── README.md
├── .gitattributes
├── setup/
│   └── virtualbox-fedora-setup.md
├── linux/
│   ├── 01-users-and-permissions.md
│   ├── 02-processes-and-services.md
│   ├── 03-packages-and-filesystem.md
│   ├── 04-ssh.md
│   └── 05-logs-and-troubleshooting.md
├── networking/
│   ├── 01-network-configuration.md
│   ├── 02-routing-and-connectivity.md
│   ├── 03-dns.md
│   ├── 04-firewall.md
│   └── 05-network-troubleshooting.md
├── scripts/
│   ├── system-check.sh
│   └── network-check.sh
└── evidence/
    ├── README.md
    └── linux/
        ├── 01-users-permissions.png
        ├── 02-httpd-service.png
        ├── 04-ssh-key-login.png
        └── 05-troubleshooting.png
```

## Labs

| # | Lab | Main commands / topics | Status |
|---|---|---|---|
| 01 | Users, groups, permissions | `useradd`, `usermod`, `id`, `chown`, `chmod`, setgid, umask | ✅ |
| 02 | Processes and services | `ps`, `pgrep`, signals, `systemctl`, `ss` | ✅ |
| 03 | Packages and filesystem | `dnf`, `rpm`, `lsblk`, `df`, `du`, `stat`, links | ✅ |
| 04 | SSH | `sshd`, keys, `authorized_keys`, password authentication | ✅ |
| 05 | Logs and troubleshooting | `journalctl`, service config, executable files, CRLF | ✅ |
| N1 | Network configuration | `ip`, `nmcli`, DHCP/static IP, hostname | ✅ |
| N2 | Routing and connectivity | `ip route`, `ping`, `tracepath`, `curl`, `nc` | ✅ |
| N3 | DNS | `resolvectl`, `dig`, `getent`, `/etc/hosts`, DNS settings | ✅ |
| N4 | Firewall | firewalld zones, services, ports, runtime/permanent rules | ✅ |
| N5 | Network troubleshooting | DNS failure and firewall/SSH failure | ✅ |

All labs were run in this order on the Fedora VM. Inside the `networking/` files, "Lab N"
refers to `networking/0N` (shown as N1–N5 here); the `linux/` files use `Linux Lab 0N`.

## Troubleshooting scenarios

The project includes four failures that I created on purpose:

| Scenario | Lab |
|---|---|
| Web server fails after a config change | `linux/05` |
| Script fails because of permissions or CRLF | `linux/05` |
| IP connectivity works but DNS does not | `networking/05` |
| Service is listening but remote access is blocked | `networking/05` |

I created and solved all four failures during the labs. The format is always the same:
symptom → checks → cause → fix → verify. The notes in each lab file describe what I
observed and which command gave the cause away.

## Scripts

Both scripts only read system information and return a non-zero exit code when a check finds a
problem. They do not need `sudo`.

```bash
./scripts/system-check.sh
./scripts/network-check.sh
```

`system-check.sh` checks hostname, OS, kernel, uptime, load, memory, disk usage for `/` and
`/home`, the state of `sshd`, `firewalld`, and `NetworkManager`, failed systemd units, and the
top five processes by memory. It returns `1` when warnings were found.

`network-check.sh` checks interfaces, IP addresses, active NetworkManager connections, the
default route and gateway, IP reachability, DNS resolution, HTTPS, and listening TCP ports.
It returns `1` when one or more checks fail.

## Reproducing the lab

1. Create the Fedora VM using `setup/virtualbox-fedora-setup.md`.
2. Take the `clean-install` snapshot.
3. Run the labs in order: `linux/01` through `linux/05`, then `networking/01` through
   `networking/05`.
4. Compare your own output with the "What actually happened" notes in each lab file.

## Evidence

Screenshots are kept only for the Linux labs, in `evidence/linux/`, and the exact policy is in
`evidence/README.md`. The networking labs have no screenshots. Command output shown in the lab
files is labelled as illustrative when it is an example. No passwords, private keys, tokens or
other secrets are stored in the repository.

## Scope and limitations

This is a single-VM Fedora lab. Testing from a second machine is replaced by tests from the
VirtualBox host where needed. IPv6, VLANs, routing protocols, VPNs, deep SELinux work, and
production hardening are outside the scope of these labs.

The scripts are intentionally small. They do not include argument parsing, logging frameworks,
or a larger monitoring framework.

## What the labs demonstrate

- **Permissions:** shared directory with owner, group, `chmod`, setgid and umask, tested with
  users inside and outside the group.
- **Processes and services:** finding and signalling processes, `systemctl` states, the
  difference between `stop` and `disable`, and checking listeners with `ss`.
- **Packages and filesystem:** `dnf`/`rpm` queries, `lsblk`, `df`, `du`, `stat`, and hard vs
  symbolic links.
- **SSH:** key-based login, `authorized_keys` permissions, and password login disabled with a
  config drop-in.
- **Logs and troubleshooting:** a broken Apache config and script permission/CRLF errors,
  solved from `journalctl`, `file` and `cat -A` evidence.
- **Networking:** NetworkManager (`nmcli`) static IP vs DHCP, routing and the default route,
  DNS with `resolvectl` and `dig`, firewalld zones with runtime vs permanent rules, and
  a fixed order of checks that separates DNS, routing, service and firewall problems.

## Notes

The commands are written for Fedora. Ubuntu/Debian alternatives are intentionally not covered.
The project is written in English to match the command names and documentation used on Linux.
