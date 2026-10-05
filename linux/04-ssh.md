# Lab 04 — SSH (Remote Login Done Properly)

**Estimated time:** 35–45 min · **Prerequisite:** Labs 01–02 optional; VM has a host-only
adapter (see `setup`).
**Related:** the firewall part uses `networking/04`; the `Permission denied` line is reused
in `networking/05` (Scenario B).

## 1. Objective

Get SSH working between the **host machine** and the **Fedora VM**, switch from password
login to key login, and then turn password login off and prove that it is really off.
SSH is also the transport I use to copy screenshots from the host into the VM.

## 2. Environment

| Where | What |
|---|---|
| Host machine | `<fill in: Windows 11 / macOS / Linux>`, OpenSSH client (built in on Windows 10+) |
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

This is how host-side screenshots get into the repo:

**Run this on the host machine**

```bash
scp firewall-test.png student@192.168.56.101:~/linux-networking-lab/evidence/networking/
```

## 5. Expected result

- `systemctl is-active sshd` → `active`, a listener on port 22.
- `ssh student@192.168.56.101` from the host works, first with a password, then without.
- `who` inside the session shows a session from the host's IP.
- After the drop-in: key login works, `PreferredAuthentications=password` fails with
  `Permission denied (publickey)`.
- `scp` moves a file from the host into the VM.

## 6. What actually happened

> _Run the steps and write 4–8 lines here with your real results: the IP of your VM, the
> fingerprint question at first login, whether the key login worked first try, and what the
> `Permission denied (publickey)` test printed. Your own words, your own output._

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

## 8. Evidence to capture

- `evidence/linux/04-ssh-key-login.png` — **from the host**: the `ssh student@192.168.56.101`
  session with no password prompt, plus `hostname`/`who` typed inside the session.
  (Take this screenshot on the host machine.)
- `evidence/linux/04-password-auth-disabled.png` (optional) — the
  `Permission denied (publickey)` line and the content of `10-lab.conf`.

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: Why is key login safer
> than a password (and why does a passphrase still matter)? Why does sshd care about the
> permissions of `authorized_keys`? What is the difference between reloading and restarting
> sshd? Why did I use a drop-in file instead of editing `sshd_config`?_
