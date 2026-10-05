# Lab 02 — Processes and systemd Services

**Estimated time:** 30–40 min · **Prerequisite:** Lab 01 not required; `setup` done.
**Related:** the `httpd` service installed here is used again in Lab 03 and in the
firewall lab (`networking/04`).

## 1. Objective

Learn to find a running process, read its state, stop it with the right signal, and manage
a real service (`httpd`) with `systemctl` — including the difference between `stop` and
`disable`.

## 2. Environment

- Fedora Workstation in VirtualBox, normal user with sudo.
- Service used: `httpd` (Apache), installed with `dnf` in Step 4.

## 3. What I needed to do

1. Find processes: `ps`, `pgrep`, `top`.
2. Start a long-running process in the background and kill it correctly (TERM, then KILL).
3. Install `httpd`, start it, and prove it is serving on port 80.
4. Stop it, see what breaks, start it again.
5. Understand `enable` vs `start` and check which services are enabled at boot.

## 4. Commands used

### Step 1 — look at processes

**Run this on Fedora**

```bash
ps -ef | head -5                  # every process, with PID and parent
ps aux --sort=-%cpu | head -6     # the 5 hungriest processes by CPU
pgrep -a sshd                     # find by name, -a prints the full command line
```

Reading `ps -ef` columns: `UID PID PPID C STIME TTY TIME CMD`. `PPID` is the parent
process — every process has a parent, and killing a parent can take its children with it.

### Step 2 — the process I created myself

**Run this on Fedora**

```bash
sleep 900 &          # "&" runs it in the background so I keep my shell
jobs                 # jobs of this shell
pgrep -af "sleep 900"
ps -o pid,ppid,stat,etime,cmd -p "$(pgrep -f 'sleep 900')"
```

Then stop it:

```bash
kill "$(pgrep -f 'sleep 900')"    # SIGTERM: "please stop". A sleep process exits here.
pgrep -af "sleep 900"             # empty = it is gone
```

If a process refuses to die, `kill -9 <PID>` (SIGKILL) is the last resort: the process
cannot catch it and cannot clean up, so it should not be the first thing I try.

### Step 3 — `top`, briefly

**Run this on Fedora**

```bash
top
```

Keys: `P` sort by CPU, `M` sort by memory, `q` to quit. `load average` in the top-right is
the number of processes waiting for CPU (1, 5 and 15 minute averages).

### Step 4 — install and run a real service

**Run this on Fedora**

```bash
sudo dnf install -y httpd

sudo systemctl enable --now httpd     # --now = enable (at boot) + start (right now)
systemctl status httpd --no-pager
systemctl is-active httpd
systemctl is-enabled httpd
```

`--no-pager` matters: without it, `systemctl status` opens the output in `less` and a
screenshot looks like a pager instead of a result.

Now check it from the outside (still on the VM):

```bash
sudo ss -tlnp | grep :80      # who is listening on port 80 (sudo shows the process name)
curl -I http://localhost      # the HTTP status line is enough for me
```

**Example output — your result may differ**

```text
$ systemctl is-active httpd
active
$ curl -I http://localhost
HTTP/1.1 200 OK
```

A note on SELinux: Fedora runs it in enforcing mode (`getenforce` → `Enforcing`). Serving
files from a non-standard directory can fail even with correct Unix permissions, because
SELinux looks at file labels too. When a service fails with a "permission denied" that Unix
permissions cannot explain: `sudo ausearch -m avc -ts recent` shows the denials.

### Step 5 — stop / start / enable / disable

**Run this on Fedora**

```bash
sudo systemctl stop httpd
systemctl is-active httpd       # inactive
systemctl is-enabled httpd      # still "enabled"! stop ≠ disable
curl -I http://localhost        # now it fails: nothing is listening
sudo ss -tlnp | grep :80        # no output: no listener at all

sudo systemctl start httpd
curl -I http://localhost        # works again
```

- `stop` = stop it now. `disable` = do not start it at the next boot.
- A stopped service that is still "enabled" comes back after a reboot. That surprised me.
- If a service is not listening at all, the clients see **Connection refused**; if a
  firewall drops the traffic, clients see a **timeout** instead. That difference is used
  again in `networking/05`.

### Step 6 — services at boot and failed units

**Run this on Fedora**

```bash
systemctl list-unit-files --type=service --state=enabled | head -15
systemctl --failed --no-pager
systemctl cat httpd | head -20      # where the unit file lives and what it runs
```

`systemctl cat` shows the unit file contents (`/usr/lib/systemd/system/httpd.service`
here). `/usr/lib` = shipped by the package; `/etc/systemd/system` = my overrides. If I ever
edit a unit file, `sudo systemctl daemon-reload` is required before the change is used.

## 5. Expected result

- `pgrep -af "sleep 900"` finds my process, `kill` removes it.
- `httpd` is `active (running)` and `enabled`.
- `curl -I http://localhost` returns `HTTP/1.1 200 OK`.
- After `systemctl stop httpd`: nothing listens on 80 and curl fails; `is-enabled` is still
  `enabled`.
- `systemctl --failed` lists no failed units.

## 6. What actually happened

> _Run the steps on your VM, then write 4–8 lines here with your real output. Mention the
> real PID numbers and the real `curl` output you got, in your own words._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `systemctl start ssh` → unit not found | The service is called `sshd` on Fedora | `systemctl list-unit-files 'sshd*'` |
| `httpd` starts then dies immediately | Bad config or a port conflict | `systemctl status httpd --no-pager`, `sudo journalctl -xeu httpd` |
| Port 80 busy | Something else (a container, another server) is on 80 | `sudo ss -tlnp \| grep :80` |
| `curl: (7) Failed to connect` | No listener → service stopped, or it is listening on another address | `systemctl is-active httpd`, `sudo ss -tlnp` |
| `kill <PID>` does nothing | The process ignores SIGTERM (it has a handler) | `ps -o stat -p <PID>`, then `kill -9` and note *why* in section 6 |
| A service cannot read a file although permissions look right | SELinux label problem | `sudo ausearch -m avc -ts recent`, `ls -Z file` |

## 8. Evidence to capture

- `evidence/linux/02-process-signals.png` — `pgrep -af "sleep 900"`, the `kill`, and the
  empty `pgrep` afterwards (one terminal, one screenshot).
- `evidence/linux/02-httpd-service.png` — `systemctl status httpd` (active) + `curl -I`
  answer + `sudo ss -tlnp | grep :80`.

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: What is the difference
> between `stop` and `disable`? Why prefer SIGTERM before SIGKILL? Why does a background
> `sleep` survive my shell closing but not a reboot? What did `PPID` tell me about how
> processes are started?_
