# Lab 03 — Packages and Filesystem Basics

**Estimated time:** 25–35 min · **Prerequisite:** Lab 02 (httpd is installed here and used
again as the example package).

## 1. Objective

Install, inspect and remove packages the Fedora way (`dnf` + `rpm`), then look at the
disks: which filesystem is used, how full it is, where the space goes, and the difference
between a hard link and a symbolic link.

## 2. Environment

- Fedora Workstation in VirtualBox, normal user with sudo.
- Example packages: `htop` (install → remove demo), `httpd` (installed in Lab 02).

## 3. What I needed to do

1. Search for a package, look at its details, install and remove it.
2. Find out which package owns a file, and which files a package installed.
3. Look at the package history.
4. Look at the block devices, the filesystem and the free space.
5. Show the difference between `ls -l`, `stat`, a symlink and a hard link.

## 4. Commands used

### Step 1 — dnf: search, info, install, remove

**Run this on Fedora**

```bash
dnf search htop                 # find the package
dnf info htop                   # version, size, description before installing
sudo dnf install -y htop        # install it
rpm -q htop                     # is it really installed? (rpm queries what is on disk)
sudo dnf remove -y htop         # and remove it again
rpm -q htop                     # "package htop is not installed" — also a result
```

`dnf` = the tool that resolves dependencies and installs; `rpm` = the tool that knows what
is installed right now. `dnf remove` is not the same as `rm`: it also removes what the
package needed.

### Step 2 — who owns which file

**Run this on Fedora**

```bash
rpm -qf /usr/sbin/httpd        # which package owns this file
rpm -ql httpd | head -10       # the files httpd installed
rpm -qi httpd | head -8        # package info (version, install date, license)
dnf provides /usr/sbin/sshd    # which package would provide a file (here: openssh-server)
dnf provides /usr/bin/dig      # (bind-utils, installed during setup)
```

`dnf provides` is the command I will really use: "a command is missing — which package do
I install?".

### Step 3 — history

**Run this on Fedora**

```bash
dnf history list | head -10
```

Every install/remove/upgrade is a transaction with an ID. On Fedora 41+ `dnf` is DNF5, and
DNF5 requires the sub-command (`dnf history list`). A bare `dnf history` gives an
"Unknown argument" error there — not a broken system.

### Step 4 — disks, filesystem, space

**Run this on Fedora**

```bash
lsblk -f                    # block devices and which filesystem is on them
findmnt /                   # what is mounted as root
df -h                       # space used, human readable
df -i                       # inodes used — "no space left" can also mean "no inodes left"
sudo du -sh /var/log        # how much space one directory uses
sudo du -sh /var/log/* 2>/dev/null | sort -h | tail -5   # the biggest items in /var/log
```

What I found in my VM: Fedora Workstation installs **Btrfs** by default, so `df` and
`lsblk -f` show `btrfs` and the layout depends on the installer options (Fedora Server may
use LVM + XFS/ext4). The exact layout does not matter for these labs — what matters is that
I can read it from the commands above.

`du` walks the files and reports real usage; `df` asks the filesystem. When they disagree,
deleted-but-still-open files are a classic reason (`sudo lsof +L1`).

### Step 5 — files, `stat`, links

**Run this on Fedora**

```bash
mkdir -p ~/lab/files && cd ~/lab/files
echo "hello lab" > notes.txt
ls -l notes.txt
stat notes.txt              # permissions, owner, size, timestamps, inode number

ln notes.txt hard.txt       # hard link: same inode, same content
ln -s notes.txt soft.txt    # symbolic link: a small file that points to notes.txt
ls -li                      # -i shows inode numbers: hard.txt == notes.txt, soft.txt is different
cat soft.txt                # reading through the symlink works

rm notes.txt                # now the interesting part
cat hard.txt                # still works (the data is still referenced)
cat soft.txt                # broken symlink: "No such file or directory"
ls -l                       # soft.txt is shown in red because its target is gone
```

A hard link is a second name for the same data; a symlink is a file that contains a path.
That is why a symlinked config file keeps working after the original is *moved*, and a
symlink to a *deleted* file does not.

### Step 6 — find files (short)

**Run this on Fedora**

```bash
find ~/lab -name '*.txt' -type f
find /var/log -name '*.log' 2>/dev/null | head -5
```

`find` needs `sudo` for directories my user cannot read — the `2>/dev/null` only hides the
permission errors, it does not fix them. `locate` is faster but needs the `mlocate`
database to be up to date, so I stayed with `find`.

## 5. Expected result

- `htop` installs, `rpm -q htop` confirms it, `dnf remove` removes it, `rpm -q` says it is
  not installed.
- `rpm -qf /usr/sbin/httpd` → `httpd-...`, `dnf provides /usr/sbin/sshd` → `openssh-server`.
- `df -h`, `df -i`, `du -sh /var/log` all return numbers without errors.
- `hard.txt` still readable after deleting `notes.txt`; `soft.txt` broken.

## 6. What actually happened

> _Run the steps on your VM and write 4–8 lines here: which filesystem your root is
> (`lsblk -f` / `findmnt /`), how much space `/var/log` uses, and what the link test
> showed. Use your own numbers._

## 7. Troubleshooting (if something goes wrong)

| Symptom | Usual reason | Check with |
|---|---|---|
| `dnf history` → "Unknown argument" | DNF5 (Fedora 41+) needs a sub-command | `dnf history list` |
| `Error: This command has to be run with superuser privileges` | Forgot `sudo` | — |
| `dnf remove` wants to remove many packages | Removing a library others depend on | Read the transaction list before typing `y` |
| `dnf provides <file>` returns nothing | The path is wrong, or it is a path created by a service, not by a package | `rpm -qf <file>` if the file exists |
| `du: cannot read directory ... Permission denied` | Not root for someone else's directory | `sudo du -sh <path>`, or ignore with `2>/dev/null` |
| `df` shows a full disk but `du` disagrees | Deleted file still held open by a process | `sudo lsof +L1` |
| Broken symlink after a package update | The symlink points to an old versioned path | `ls -l <link>`, `readlink <link>` |

## 8. Evidence to capture

- `evidence/linux/03-packages.png` — `rpm -qf /usr/sbin/httpd`, `rpm -ql httpd | head`,
  `dnf provides /usr/sbin/sshd` and the `dnf history list` output.
- `evidence/linux/03-disk-usage.png` — `lsblk -f`, `df -h`, `du -sh /var/log` (and the link
  test `ls -li` / `cat hard.txt` if there is room).

## 9. What I learned

> _Write this yourself after running the lab, 4–8 lines. Prompts: dnf vs rpm — when do I
> use which? What is an inode, and how does the hard-link test prove what a hard link is?
> Why can "no space left on device" happen with free space in `df -h`?_
