# Lab 01 — Users, Groups and Permissions

**Estimated time:** 30–40 min · **Prerequisite:** `setup/virtualbox-fedora-setup.md` done.
**Related:** file ownership is also used in Lab 04 (`~/.ssh` permissions).

## 1. Objective

Create lab users and a shared group, then build a shared directory where members of the
group can work and everybody else cannot, and explain how the permissions (`r`, `w`, `x`),
the ownership and the umask produce that result.

## 2. Environment

- Fedora Workstation in VirtualBox (my VM: `<fill in: hostname>`), normal user with sudo.
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

**Example output — your result may differ**

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

**Example output — your result may differ**

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

**Example output — your result may differ**

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

> _Run the steps above on your VM, then write 4–8 honest lines here: what worked
> immediately, what surprised you, and the real output you got. Do not copy the example
> output — put your own. If you fixed something, mention it briefly (details go in
> section 7)._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `useradd: user 'alice' already exists` | The user is already there, probably from an earlier run | `id alice`, `getent passwd alice` |
| `alice` is in `devs` in `id alice` but not inside her shell | Her shell started before the change | `su - alice -c id`, or `newgrp devs` |
| `carol` can `ls` but not write | Something is missing from the `chown`/`chmod` step | `ls -ld /srv/labproject`, `namei -l /srv/labproject` |
| `Permission denied` on `/srv` itself | `/srv` also needs `x` for others, or SELinux blocked it | `ls -ld /srv`, `getenforce`, `sudo ausearch -m avc -ts recent` |
| Files do **not** get group `devs` | setgid bit missing or the directory was recreated | `ls -ld /srv/labproject` (look for the `s`) |
| `su - alice` asks for a password you never set | You skipped `passwd alice` | `sudo passwd alice`, or use `sudo -u alice -i` |

## 8. Evidence to capture

One screenshot is enough:

- `evidence/linux/01-users-permissions.png` — must show: `id alice` + `id carol`,
  `ls -ld /srv/labproject` (with the `s`), `ls -l /srv/labproject` (files with group `devs`)
  and the `Permission denied` for carol. If it does not fit in one terminal, take a second
  screenshot named `01-users-permissions-2.png`.

## 9. What I learned

> _Write this section yourself after running the lab, in 4–8 lines. Prompts, if you need
> them: Why does a shared directory need setgid and not only `chmod 770`? Why do file
> permissions start from `666` and directories from `777`? Why is `usermod -aG` dangerous
> without the `-a`? What is the difference between "user exists" and "the running shell
> already has the new group"?_
