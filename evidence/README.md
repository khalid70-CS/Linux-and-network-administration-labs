# Evidence

Screenshots are only used when they prove something that command text alone does not.

## Rules

1. Keep the screenshot focused on the relevant terminal output.
2. Aim for 1–2 screenshots per lab.
3. Do not include passwords, tokens, private keys, or other secrets.
4. PNG is preferred; keep files reasonably small (about 300 KB or less when practical).
5. No screenshot is better than a screenshot that does not prove anything.

## Naming

Use:

`evidence/<area>/<lab-number>-<short-description>.png`

Examples:

```text
evidence/linux/01-users-permissions.png
evidence/networking/04-host-test.png
```

## Where screenshots come from

For VM tests, use the Fedora screenshot tool and copy the image from
`~/Pictures/Screenshots`. For tests that must come from the host, take the screenshot there and
move it into the matching `evidence/` directory. A VirtualBox shared folder can also be used.

Example host-side copy after SSH is configured:

```bash
scp firewall-test.png student@192.168.56.101:~/linux-networking-lab/evidence/networking/
```

## Checklist

### Linux

- [ ] `linux/01-users-permissions.png` — Lab 01: users/groups, shared directory, denied write
- [ ] `linux/02-process-signals.png` — Lab 02: process, signal, process gone
- [ ] `linux/02-httpd-service.png` — Lab 02: service status, HTTP response, port 80
- [ ] `linux/03-packages.png` — Lab 03: `rpm -q`, `dnf info`, `dnf history`
- [ ] `linux/03-disk-usage.png` — Lab 03: `lsblk`, `df -h`, `du -sh`
- [ ] `linux/04-ssh-key-login.png` — Lab 04: key-based SSH login
- [ ] `linux/04-password-auth-disabled.png` — Lab 04: password login refused (optional)
- [ ] `linux/05-scenario-a-config-error.png` — Lab 05: bad config and recovery
- [ ] `linux/05-scenario-b-script.png` — Lab 05: permission/CRLF failure and fix

### Networking

- [ ] `networking/01-nmcli-static-ip.png` — Lab 01: connection settings and IP
- [ ] `networking/02-routes.png` — Lab 02: route table, route lookup, break/fix
- [ ] `networking/02-tracepath.png` — Lab 02: `tracepath` (optional)
- [ ] `networking/03-dns.png` — Lab 03: `resolvectl`, `dig`, `getent`
- [ ] `networking/04-zone-rules.png` — Lab 04: active zone, ports, rule file
- [ ] `networking/04-host-test.png` — Lab 04: host-side firewall test
- [ ] `networking/05-scenario-a-dns-failure.png` — Lab 05: DNS failure and fix
- [ ] `networking/05-scenario-b-firewall.png` — Lab 05: SSH blocked by firewall and fix

### Scripts

- [ ] `networking/00-network-check-output.png` — `./network-check.sh` output
