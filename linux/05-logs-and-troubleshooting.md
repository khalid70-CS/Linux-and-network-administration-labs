# Lab 05 — Logs and Troubleshooting (2 Scenarios)

**Estimated time:** 40–50 min · **Prerequisite:** Lab 02 (httpd) and Lab 04 (to practise
like a real admin: SSH from the host, keep the VM console for emergencies).
**Snapshot recommended before this lab.**

## 1. Objective

Read system logs with `journalctl`, then solve two small problems that I created myself:
a service that will not start after a config change, and a script that will not run.
The method matters more than the fix: **symptom → investigate → find → fix → verify**.

## 2. Environment

- Fedora Workstation in VirtualBox, sudo, `httpd` installed in Lab 02.
- Files created during this lab: `/etc/httpd/conf.d/lab.conf` (bad config),
  `~/lab/troubleshooting/*.sh` (test scripts).

## 3. What I needed to do

1. Learn the `journalctl` commands I actually use (not all of them).
2. **Scenario A:** break the httpd config on purpose, restart, and find out why it failed.
3. **Scenario B:** a script fails to run — find out whether it is a permission problem or a
   line-ending problem, and fix it properly.

## 4. Commands used

### Part 0 — the journal, briefly

**Run this on Fedora**

```bash
journalctl -b -p err --no-pager | tail -20      # errors since the current boot
journalctl -u httpd -n 30 --no-pager            # logs of one unit
journalctl -xeu httpd --no-pager                # -x adds explanations, -e jumps to the end
journalctl --since "10 min ago" --no-pager      # time window (natural language works)
journalctl -f                                   # follow live logs (Ctrl+C to stop)
sudo journalctl -b -1 -n 20 --no-pager          # logs of the previous boot
```

Where logs live on Fedora: `journald` keeps them, and `journalctl` reads them. If
`/var/log/messages` or `/var/log/secure` exist on a machine, that means the optional
`rsyslog` package is writing plain text files there too (a default Workstation install does
not have them). Lab 04's SSH logs are an example: `sudo journalctl -u sshd -n 20`.

---

### Scenario A — "I changed a config file and now the web server is dead"

**Symptom:** after editing an Apache config file, `httpd` does not come back up. From the
host, the web page that worked yesterday is now unreachable.

**Step 1 — create the fault (this is the "bad" part, on purpose)**

**Run this on Fedora**

```bash
sudo tee /etc/httpd/conf.d/lab.conf >/dev/null <<'EOF'
# Lab 05: this line is not a real Apache directive
ServeName lab.local
EOF

sudo systemctl restart httpd
```

**Step 2 — investigate**

**Run this on Fedora**

```bash
systemctl status httpd --no-pager      # "failed" + the last log lines
systemctl is-active httpd
sudo journalctl -xeu httpd --no-pager | tail -30
sudo ss -tlnp | grep :80               # nothing listening → no web service
curl -I http://localhost               # -> Failed to connect (nothing is there)
hostname -I; curl -I http://$(hostname -I | awk '{print $1}')
```

What I look for in the journal output: the line with the error, not the whole page.
In this case a line like:

**Example output — your result may differ**

```text
httpd[1234]: AH00526: Syntax error on line 2 of /etc/httpd/conf.d/lab.conf:
httpd[1234]: Invalid command 'ServeName', perhaps misspelled or defined by a module not included in the server configuration
systemd[1]: httpd.service: Main process exited, code=exited, status=1/FAILURE
```

**Step 3 — a faster check next time**

**Run this on Fedora**

```bash
sudo apachectl configtest     # Apache-only: tests the config without starting the service
```

`apachectl configtest` (or `httpd -t`) prints the same syntax error without touching the
running service. Testing the config *before* restarting is the habit that avoids this whole
scenario. It is Apache-specific — other services have their own check or none.

**Step 4 — fix and verify**

**Run this on Fedora**

```bash
sudo rm /etc/httpd/conf.d/lab.conf      # the file was the problem, not the service
# (or fix the typo with: sudoedit /etc/httpd/conf.d/lab.conf)
sudo apachectl configtest               # -> Syntax OK
sudo systemctl restart httpd
systemctl is-active httpd               # active
curl -I http://localhost                # HTTP/1.1 200 OK again
sudo journalctl -u httpd --since "5 min ago" --no-pager | tail -5
```

**What I must be able to explain afterwards:** why `systemctl restart httpd` alone will
never help while the config is broken, and why the useful error was in the journal and not
in the terminal.

---

### Scenario B — "my script does not run"

**Symptom:** a script I wrote runs in one way and fails in another, with different messages.

**Step 1 — the permission part**

**Run this on Fedora**

```bash
mkdir -p ~/lab/troubleshooting && cd ~/lab/troubleshooting

cat > hello.sh <<'EOF'
#!/bin/bash
echo "the script ran fine"
EOF

./hello.sh            # -> bash: ./hello.sh: Permission denied   (no execute bit)
bash hello.sh         # -> works! bash reads the file, it does not need the x bit
ls -l hello.sh        # -> -rw-r--r-- : no x

chmod +x hello.sh
./hello.sh            # -> the script ran fine
```

**Step 2 — the line-ending part**

**Run this on Fedora**

```bash
# printf with \r\n creates the same file a Windows editor or a copy-paste from Windows makes
printf '#!/bin/bash\r\necho "the script ran fine"\r\n' > crlf-script.sh
chmod +x crlf-script.sh

./crlf-script.sh      # -> bash: ./crlf-script.sh: /bin/bash^M: bad interpreter: No such file or directory
```

That message is not random: the kernel reads everything after `#!` as the interpreter path,
and it literally tried to run `/bin/bash<carriage-return>`.

**Step 3 — investigate instead of guessing**

**Run this on Fedora**

```bash
file crlf-script.sh                 # -> ASCII text, with CRLF line terminators
head -1 crlf-script.sh | cat -A     # -> #!/bin/bash^M$   (^M = \r, $ = end of line)
bash crlf-script.sh                 # even this fails now, with a quoting/command error
od -c crlf-script.sh | head -2      # byte view, if I want to be 100% sure
```

**Step 4 — fix and verify**

**Run this on Fedora**

```bash
sed -i 's/\r$//' crlf-script.sh     # delete the carriage return at the end of every line
file crlf-script.sh                 # -> ASCII text
./crlf-script.sh                    # -> the script ran fine
```

Alternative if `dos2unix` is installed (`sudo dnf install -y dos2unix`):
`dos2unix crlf-script.sh`.

**What I must be able to explain afterwards:** the difference between "the file is not
executable" (kernel refuses to run it → `Permission denied`, but `bash file.sh` still
works) and "the interpreter path is broken" (the error names the interpreter, `^M` in the
path). And that `file` / `cat -A` are the quick way to see invisible characters.

---

### The checklist I would follow for any "it does not work"

1. What exactly is the symptom? Which error message, from which command?
2. Is the process/service running? `systemctl status X --no-pager`
3. What does the log say? `journalctl -u X -n 30 --no-pager` (and `-xeu` when needed).
4. Is it listening / where does it fail? `ss -tlnp`, `curl`, `./script.sh`
5. Is the config valid? `apachectl configtest`, `sshd -t`, or the tool's own check.
6. Is the environment right? permissions (`ls -l`), SELinux (`getenforce`,
   `ausearch -m avc -ts recent`), firewall (`firewall-cmd --list-all`).
7. Fix the cause, then verify with the *same* command that failed before.

## 5. Expected result

- Scenario A: `httpd` fails to start, the journal names the bad directive and the file, and
  after removing the file, `curl -I http://localhost` returns `HTTP/1.1 200 OK`.
- Scenario B: `./hello.sh` fails without `+x` and works with it; the CRLF script fails with
  `bad interpreter`, runs after `sed -i 's/\r$//'`.

## 6. What actually happened

> _Run both scenarios and write 6–10 lines here: the exact error lines you got, how long it
> took you to find the cause, and which command gave it away. If you were stuck, say where
> you got stuck — that is the most useful part of this file._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `journalctl: command not found` | Very unusual on Fedora (systemd always ships it) | `rpm -q systemd` |
| The journal is empty for a unit | The service name is wrong | `systemctl list-units 'httpd*'` |
| `apachectl configtest` → "command not found" | Not installed (package `httpd` provides it) | `rpm -q httpd`, `ls /usr/sbin/apachectl` |
| The bad config file is back after a restart | A leftover file, or it was restored from a snapshot | `ls -l /etc/httpd/conf.d/`, `grep -rn ServeName /etc/httpd/` |
| `sed -i` says "Permission denied" | The file is root-owned | `sudo sed -i 's/\r$//' <file>` |
| The script still fails after the fix | A second, different problem (e.g. a bad path inside it) | `bash -x ./script.sh` shows every line as it runs |

## 8. Evidence to capture

- `evidence/linux/05-scenario-a-config-error.png` — the failed `httpd` status/journal error
  **and** the healthy state after the fix (the `200 OK` from `curl -I`).
- `evidence/linux/05-scenario-b-script.png` — `Permission denied` → works after `chmod +x`,
  and the `bad interpreter` error → works after the `sed` fix.

  If the two halves do not fit in one window, take two screenshots each and name them
  `-1.png` / `-2.png` — keep the numbers low.

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: Why is the journal better
> than the terminal output for a failed service? What does `systemctl status` tell me that
> `journalctl` does not (and the other way round)? What is the fastest way to tell a
> permission problem from a line-ending problem?_
