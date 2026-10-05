# Linux Lab 04 — SSH (Remote Login Done Properly)

**Estimated time:** 35–45 min · **Prerequisite:** Labs 01–02 optional; VM has a host-only
adapter (see `setup`).
**Related:** the firewall part uses `networking/04`; the `Permission denied` line is reused
in `networking/05` (Scenario B).

## 1. Objective

Get SSH working between the **host machine** and the **Fedora VM**, switch from password
login to key login, and then turn password login off and prove that it is really off.
SSH is also a convenient way to copy files from the host into the VM.

## 2. Environment

| Where | What |
|---|---|
| Host machine | Windows 11, OpenSSH client (built in) in PowerShell |
| Fedora VM | `openssh-server`, interface `enp0s8` (host-only) with IP `192.168.56.10x` |
| Wire between them | VirtualBox host-only network (`192.168.56.0/24`) |

> The host can only reach the VM through the **host-only** adapter. The NAT adapter
> (`enp0s3`) is for the VM's internet access and cannot be reached from the host.

## 3. What I needed to do

1. Make sure `sshd` is installed, running and enabled.
2. Log in from the host with a password.
3. Create a key pair and set up key login (`authorized_keys` with the correct permissions).
4. Disable password login in a small config drop-in, verify, and know how to revert it.

## 4. Commands used

### Step 1 — server side: is sshd running?

**Run this on Fedora**

```bash
rpm -q openssh-server          # installed?
sudo dnf install -y openssh-server    # only if the line above said "not installed"

sudo systemctl enable --now sshd
systemctl status sshd --no-pager
sudo ss -tlnp | grep :22       # is something listening on 22?

ip -brief addr show enp0s8     # the IP the host will connect to
```

Fedora notes: the service is `sshd` (not `ssh`), and it is already allowed in the firewall
by default (`sudo firewall-cmd --query-service=ssh` should print `yes` in both the
`FedoraWorkstation` and the `public` zone).

### Step 2 — client side: first login with a password

**Run this on the host machine** (PowerShell / Terminal — not inside the VM)

```bash
ssh student@192.168.56.101
```

- First time: "The authenticity of host ... can't be established" → type `yes`.
  That stores the VM's host key in `~/.ssh/known_hosts`. The fingerprint should match the
  one on the VM: `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`.
- Then the prompt `student@192.168.56.101's password:` → type your VM user's password.

If it never asks for a password and just hangs, that is a timeout, not a wrong password —
usually the wrong IP or a firewall on the way (see `networking/05`).

Once inside, check where I landed:

**Run this on Fedora (in the SSH session)**

```bash
whoami; hostname; who; pwd
```

`who` shows the login session — that is the proof that I am connected from the host, not
sitting in the VM console.

### Step 3 — key login instead of a password

**Run this on the host machine**

```bash
ssh-keygen -t ed25519 -C "fedora-lab"
# press Enter for the default path, then choose a passphrase (a passphrase protects the
# private key if the laptop is stolen; using the key agent means typing it once per session)
```

Then install the **public** key on the VM:

- Linux / macOS host:

  ```bash
  ssh-copy-id student@192.168.56.101
  ```

- Windows host (PowerShell, no `ssh-copy-id`):

  ```powershell
  type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh student@192.168.56.101 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  ```

Verify from the host (no password prompt now):

```bash
ssh student@192.168.56.101
```

And check the server side, because SSH is strict about permissions here:

**Run this on Fedora**

```bash
ls -ld ~/.ssh                     # must be drwx------ (700)
ls -l ~/.ssh/authorized_keys      # must be -rw------- (600), owned by me
tail -1 ~/.ssh/authorized_keys    # my public key: starts with "ssh-ed25519 ... fedora-lab"
```

If the permissions are too open, sshd ignores the file and asks for a password again — it
does not print a friendly error on the client. The server log is:

**Run this on Fedora**

```bash
sudo journalctl -u sshd -n 20
```

### Step 4 — turn password login off (and prove it)

First check where the config lives, then add a small drop-in instead of editing the big
file:

**Run this on Fedora**

```bash
grep -i '^Include' /etc/ssh/sshd_config     # Fedora includes /etc/ssh/sshd_config.d/*.conf

sudo tee /etc/ssh/sshd_config.d/10-lab.conf >/dev/null <<'EOF'
# Lab 04: key-only login
PermitRootLogin no
PasswordAuthentication no
EOF

sudo sshd -t                 # syntax check BEFORE reloading — no output means OK
sudo systemctl reload sshd
```

Why a drop-in: the package owns `/etc/ssh/sshd_config`, and a package update can replace
it. Files under `sshd_config.d/` are mine and survive updates. sshd uses the **first** value
it sees for a setting, and Fedora's `Include` line is at the top, so a drop-in overrides the
main file.

Verify (from the host):

```bash
# 1. key login still works
ssh student@192.168.56.101

# 2. password login must fail now
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no student@192.168.56.101
# -> Permission denied (publickey)
```

If it says `Permission denied (publickey)`, the setting is active. Keep the VirtualBox
window open while doing this — if I lock myself out of SSH, I still have the console to
revert it:

```bash
sudo rm /etc/ssh/sshd_config.d/10-lab.conf
sudo systemctl reload sshd
```

### Bonus — copy a file over SSH

Copying a file from the host into the VM:

**Run this on the host machine**

```bash
scp notes.txt student@192.168.56.101:~/
```

## 5. Expected result

- `systemctl is-active sshd` → `active`, a listener on port 22.
- `ssh student@192.168.56.101` from the host works, first with a password, then without.
- `who` inside the session shows a session from the host's IP.
- After the drop-in: key login works, `PreferredAuthentications=password` fails with
  `Permission denied (publickey)`.
- `scp` moves a file from the host into the VM.

## 6. What actually happened

On the VM I checked `rpm -q openssh-server`, ran `systemctl enable --now sshd`, and confirmed
with `systemctl status sshd` and `ss -tlnp | grep :22` that `sshd` was running and listening.
`ip -brief addr show enp0s8` gave me the host-only address that the host connects to (the
commands in this lab use `192.168.56.101`).

From the Windows 11 host I connected with `ssh student@192.168.56.101`. The first connection
showed the host-key question and I answered `yes`, so the key went into `known_hosts`. Inside
the session `whoami`, `hostname` and `who` showed that I was logged in remotely.

I created an ed25519 key pair with `ssh-keygen` and installed the public key with the
PowerShell command from the lab, because Windows has no `ssh-copy-id`. A new `ssh` login then
needed no password. On the VM `ls -ld ~/.ssh` showed `drwx------` and
`ls -l ~/.ssh/authorized_keys` showed `-rw-------`.

Password login was part of this lab, so I turned it off with the drop-in file
`/etc/ssh/sshd_config.d/10-lab.conf` (`PermitRootLogin no`, `PasswordAuthentication no`),
checked it with `sshd -t` and used `systemctl reload sshd`. Key login still worked, and the
test with `PreferredAuthentications=password` and `PubkeyAuthentication=no` was refused with
`Permission denied (publickey)`, so the setting was active. I kept the VirtualBox console open
in case I had to remove the drop-in.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `ssh: connect ... port 22: Connection refused` | sshd is not running / not installed | `systemctl status sshd --no-pager` |
| `ssh` hangs, no answer at all | Wrong IP, or traffic is dropped by a firewall | `ip -brief addr` on the VM, `nc -vz <ip> 22` from the host, `sudo firewall-cmd --query-service=ssh` |
| `Permission denied (publickey)` although the key is installed | Permissions of `~/.ssh` (700) or `authorized_keys` (600), or you are root (`PermitRootLogin no`) and keys are not set up for root | `ls -ld ~/.ssh ~/.ssh/authorized_keys`, `sudo journalctl -u sshd -n 30` |
| `Permission denied` with the correct password | Wrong user, or password login was disabled earlier in this lab | `id <user>` on the VM, `grep -r PasswordAuthentication /etc/ssh/sshd_config*` |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | The VM's host key changed (reinstall / restored snapshot) | `ssh-keygen -R 192.168.56.101`, then reconnect |
| `sshd -t` prints an error and reload fails | Typo in the drop-in | fix the file, `sudo sshd -t` again |
| Agent keeps asking for the key passphrase | Agent not loaded | `eval "$(ssh-agent -s)" && ssh-add` |

## 8. Evidence

One screenshot, taken on the host machine (the private key is never shown):

- `evidence/linux/04-ssh-key-login.png` — terminal showing `ssh student@192.168.56.101`
  logging in without a password prompt, followed by `whoami` or `hostname` inside the session.

## 9. What I learned

With key authentication the VM stores only my public key in `authorized_keys`. When I log in,
the client proves that it owns the matching private key by signing data from the server, and
the private key never leaves my host. That is why it is safer than a password: nothing secret
is sent, and there is no password to guess. The passphrase still matters because it protects
the private key file if somebody copies it.

sshd is strict about permissions on purpose. If `~/.ssh` or `authorized_keys` can be written by
other users, someone else could add a key and log in as me, so sshd ignores the file and falls
back to a password. The client prints no friendly error for this; the reason is in
`journalctl -u sshd`. The correct values are `700` for `~/.ssh` and `600` for
`authorized_keys`.

I also learned to run `sshd -t` before reloading, and to use a drop-in file so that a package
update does not overwrite my change. `reload` re-reads the configuration without dropping
existing sessions, which is safer than `restart` while I am connected.
