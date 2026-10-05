# Linux & Networking Lab

A practical Fedora lab for Linux administration, networking, SSH, and basic troubleshooting.
The project is meant to be run in a VirtualBox VM and documented with command output and a
small set of screenshots.

## Current status

The lab instructions are ready. The status table shows which labs have actually been run.
I do not count a lab as finished until the commands have been run and the notes in sections
6 and 9 have been filled in.

## What is covered

- 5 Linux labs: users and permissions, processes and services, packages and filesystem, SSH,
  and logs/troubleshooting.
- 5 networking labs: interface configuration, routing, DNS, firewalld, and network
  troubleshooting.
- 2 read-only Bash checks for system and network state.
- 4 fault scenarios used to practise troubleshooting instead of only following setup steps.

The VM is a lab machine, not a production server. No Ansible, Terraform, containers, CI/CD,
or other automation tools are required.

## Environment

| Item | Setup |
|---|---|
| Host | `<fill in: your host OS and version>` |
| Hypervisor | VirtualBox 7.x |
| Guest | Fedora Workstation, 64-bit |
| VM | 4 GB RAM, 2 CPUs, 25 GB disk |
| Adapter 1 | NAT |
| Adapter 2 | Host-only, `192.168.56.0/24` |
| User | normal user in `wheel` |

Take a snapshot before labs that intentionally change or break the system.

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
    ├── linux/
    └── networking/
```

## Labs

| # | Lab | Main commands / topics | Status |
|---|---|---|---|
| 01 | Users, groups, permissions | `useradd`, `usermod`, `id`, `chown`, `chmod`, setgid, umask | ⬜ |
| 02 | Processes and services | `ps`, `pgrep`, signals, `systemctl`, `ss` | ⬜ |
| 03 | Packages and filesystem | `dnf`, `rpm`, `lsblk`, `df`, `du`, `stat`, links | ⬜ |
| 04 | SSH | `sshd`, keys, `authorized_keys`, password authentication | ⬜ |
| 05 | Logs and troubleshooting | `journalctl`, service config, executable files, CRLF | ⬜ |
| N1 | Network configuration | `ip`, `nmcli`, DHCP/static IP, hostname | ⬜ |
| N2 | Routing and connectivity | `ip route`, `ping`, `tracepath`, `curl`, `nc` | ⬜ |
| N3 | DNS | `resolvectl`, `dig`, `getent`, `/etc/hosts`, DNS settings | ⬜ |
| N4 | Firewall | firewalld zones, services, ports, runtime/permanent rules | ⬜ |
| N5 | Network troubleshooting | DNS failure and firewall/SSH failure | ⬜ |

`⬜` means the lab is written but not yet verified on the VM. Change it to `✅` only after
running the lab and adding the required evidence.

## Troubleshooting scenarios

The project includes four failures on purpose:

| Scenario | Lab |
|---|---|
| Web server fails after a config change | `linux/05` |
| Script fails because of permissions or CRLF | `linux/05` |
| IP connectivity works but DNS does not | `networking/05` |
| Service is listening but remote access is blocked | `networking/05` |

The troubleshooting format is simple: symptom → checks → cause → fix → verify.

## Scripts

Both scripts only read system information and return a non-zero exit code when a check finds a
problem. They do not need `sudo`.

```bash
chmod +x scripts/*.sh
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
4. Fill in **What actually happened** and **What I learned** from your real output.
5. Add only the screenshots listed in `evidence/README.md`.
6. Commit the work as you go, for example:

```bash
git add .
git commit -m "lab 03: packages and filesystem"
git push
```

## Evidence

Example output is labelled as an example. Do not copy it as a real result. Keep screenshots in
`evidence/<area>/` and do not put passwords, private keys, tokens, or other secrets in the repo.
The full screenshot list is in `evidence/README.md`.

## Scope and limitations

This is a single-VM Fedora lab. Testing from a second machine is replaced by tests from the
VirtualBox host where needed. IPv6, VLANs, routing protocols, VPNs, deep SELinux work, and
production hardening are outside the scope of these labs.

The scripts are intentionally small. They do not include argument parsing, logging frameworks,
or a larger monitoring framework.

## After the labs

The final notes should make it possible to explain:

- Linux file permissions, groups, umask, and setgid.
- `systemctl` service states and where to find the useful logs.
- SSH key authentication and the important file permissions around it.
- How NetworkManager, routes, gateways, and DNS fit together.
- firewalld zones and the difference between runtime and permanent rules.
- A repeatable order for separating DNS, routing, service, and firewall problems.

## Notes

The commands are written for Fedora. Ubuntu/Debian alternatives are intentionally not covered.
The project is in English so the command names and terminology match the documentation normally
used in Linux administration.
