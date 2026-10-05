# Linux Lab 01 — Users, Groups and Permissions

**Estimated time:** 30–40 min · **Prerequisite:** `setup/virtualbox-fedora-setup.md` done.
**Related:** file ownership is also used in Linux Lab 04 (`~/.ssh` permissions).

## 1. Objective

Create lab users and a shared group, then build a shared directory where members of the
group can work and everybody else cannot, and explain how the permissions (`r`, `w`, `x`),
the ownership and the umask produce that result.

## 2. Environment

- Fedora Workstation in VirtualBox (my VirtualBox VM: `fedora-lab`), normal user with sudo.
- Users used: `alice`, `bob` (members of `devs`), `carol` (not a member).
- Target directory: `/srv/labproject`

## 3. What I needed to do

1. Create the three test users.
2. Create a group `devs` and put `alice` and `bob` in it.
3. Create `/srv/labproject`, owned by `root` and the group `devs`, with permissions that
   allow the group to work in it and block everyone else.
4. Prove the result: `alice` and `bob` can write, `carol` cannot, and files created
   inside inherit the `devs` group.
5. Look at what the umask does to new files.

## 4. Commands used

### Step 1 — create the users

**Run this on Fedora**

```bash
sudo useradd -m alice
sudo useradd -m bob
sudo useradd -m carol

sudo passwd alice      # I set a password for alice only: I want to test "su - alice" once.

id alice               # uid, gid and every group alice is in
```

Note: on Fedora, members of the group `wheel` can use `sudo`. I did **not** add the lab
users to `wheel` — they are test users, so I do things *as* them with `sudo -u`.

**Illustrative output — exact values differ per VM**

```text
$ id alice
uid=1001(alice) gid=1001(alice) groups=1001(alice)
```

### Step 2 — create the group and add members

**Run this on Fedora**

```bash
sudo groupadd devs
sudo usermod -aG devs alice     # -a = append, -G = group. WITHOUT -a you would overwrite the groups
sudo usermod -aG devs bob

getent group devs               # who is in the group, straight from /etc/group
id alice
```

One thing that confused me at first: `id alice` already shows `devs`, but a shell that
`alice` opened **before** the change does not have it, because the process groups are fixed
when the session starts. A new login (`su - alice`) or `newgrp devs` picks it up.

### Step 3 — the shared directory

**Run this on Fedora**

```bash
sudo mkdir -p /srv/labproject

sudo chown root:devs /srv/labproject   # owner = root, group = devs
sudo chmod 2770 /srv/labproject        # 2 = setgid, 770 = rwx for owner+group, nothing for others

ls -ld /srv/labproject
```

Reading `drwxrws---`: the `s` in the group position is the setgid bit. It means **new
files and directories inside get the group `devs`**, instead of the group of whoever
created them. That is what makes a shared folder actually work.

**Illustrative output — exact values differ per VM**

```text
$ ls -ld /srv/labproject
drwxrws---. 2 root devs 40 Oct  4 10:12 /srv/labproject
```

### Step 4 — prove it works (and prove it blocks)

**Run this on Fedora**

```bash
# alice writes a file
sudo -u alice touch /srv/labproject/alice-notes.txt

# bob writes a file
sudo -u bob touch /srv/labproject/bob-notes.txt

# carol is not in devs, so this must fail
sudo -u carol touch /srv/labproject/carol-notes.txt

ls -l /srv/labproject
```

Expected for the first two files: group `devs`, even though they were created by `alice`
and `bob` (that is the setgid bit doing its job). Expected for carol: `Permission denied`.

**Illustrative output — exact values differ per VM**

```text
$ ls -l /srv/labproject
-rw-r--r--. 1 alice devs 0 Oct  4 10:15 alice-notes.txt
-rw-r--r--. 1 bob   devs 0 Oct  4 10:15 bob-notes.txt
```

### Step 5 — umask

**Run this on Fedora**

```bash
umask                 # -> 0022 on Fedora
touch normal.txt
ls -l normal.txt      # -> -rw-r--r-- (666 minus 022)

umask 0077            # only for this shell session
touch private.txt
ls -l private.txt     # -> -rw------- (666 minus 077)

umask 0022            # or just open a new terminal
```

The umask is *subtracted* from the default `666` (files) / `777` (directories). It is a
per-process setting, so it disappears when the shell closes.

### Optional: compare with the sticky bit

`ls -ld /tmp` shows `drwxrwxrwt`. The `t` (sticky) bit on `/tmp` means users can only
delete **their own** files there, even though everybody can write to the directory.
setgid = "files inherit my group", sticky = "you can only remove your own files".

## 5. Expected result

- `alice` and `bob` exist, `devs` contains `alice` and `bob`, `carol` is not in it.
- `/srv/labproject` is `drwxrws--- root devs`.
- Files created by `alice`/`bob` inside have group `devs` and are readable by each other.
- `carol` gets `Permission denied` on write and on `ls`.
- `umask 0077` makes new files `-rw-------`.

## 6. What actually happened

I created the three users with `useradd -m` and set a password only for `alice`. I created
the group `devs`, added `alice` and `bob` with `usermod -aG`, and checked the result with
`id alice` and `getent group devs`. `carol` was not in the group. At first it confused me that
`id alice` already showed `devs` while a shell that `alice` had opened earlier would not have
it: the groups of a process are fixed when the session starts.

For the shared directory I used `chown root:devs /srv/labproject` and `chmod 2770`. `ls -ld`
showed `drwxrws---`, with an `s` in the group position, which is the setgid bit. Files created
with `sudo -u alice touch` and `sudo -u bob touch` got the group `devs`, not the personal group
of the user who created them. The same `touch` as `carol` failed with `Permission denied`,
which was the result I wanted to see.

For the umask I compared a new file under the default umask (`-rw-r--r--`) with a new file
after `umask 0077` (`-rw-------`). I also looked at `ls -ld /tmp` to see the sticky bit as a
different special permission.

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `useradd: user 'alice' already exists` | The user is already there, probably from an earlier run | `id alice`, `getent passwd alice` |
| `alice` is in `devs` in `id alice` but not inside her shell | Her shell started before the change | `su - alice -c id`, or `newgrp devs` |
| `carol` can `ls` but not write | Something is missing from the `chown`/`chmod` step | `ls -ld /srv/labproject`, `namei -l /srv/labproject` |
| `Permission denied` on `/srv` itself | `/srv` also needs `x` for others, or SELinux blocked it | `ls -ld /srv`, `getenforce`, `sudo ausearch -m avc -ts recent` |
| Files do **not** get group `devs` | setgid bit missing or the directory was recreated | `ls -ld /srv/labproject` (look for the `s`) |
| `su - alice` asks for a password you never set | You skipped `passwd alice` | `sudo passwd alice`, or use `sudo -u alice -i` |

## 8. Evidence

One screenshot, taken in the Fedora VM:

- `evidence/linux/01-users-permissions.png` — terminal showing `id alice` and `id carol`,
  `ls -ld /srv/labproject` (with the `s`), `ls -l /srv/labproject` (files with group `devs`)
  and the `Permission denied` for `carol`.

## 9. What I learned

Linux decides access by looking at three things in order: is the process the owner of the
file, is it in the file's group, or is it "other". The three `rwx` triplets belong to those
three classes, so `chown root:devs` and `chmod 770` together mean "group `devs` can work here,
everybody else cannot". `chmod 770` alone is not enough for a shared folder, because new files
would get the primary group of whoever creates them. The setgid bit (the `2` in `2770`) makes
new files inherit `devs`, so the other group members can still use them.

The umask removes permission bits from the starting values `666` (files) and `777`
(directories). That is why a new file is not executable by default and why `umask 0077` gives
`-rw-------`. It belongs to the running shell, so it is gone when the shell closes.

Two practical lessons: `usermod -aG` needs the `-a`, otherwise the supplementary groups are
replaced instead of extended, and "the user is in the group" (`id alice`) is not the same as
"the shell that is already running has the group". I also learned that I can test other users
safely with `sudo -u` without adding them to `wheel`.
