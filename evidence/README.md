# Evidence

Screenshots are used only for the Linux labs. The networking labs have no screenshots: they
are documented through the lab Markdown files in `networking/` (commands, what happened and
what I learned).

## Final structure

```text
evidence/
├── README.md
└── linux/
    ├── 01-users-permissions.png
    ├── 02-httpd-service.png
    ├── 04-ssh-key-login.png
    └── 05-troubleshooting.png
```

## What each screenshot proves

| File | Lab | What the terminal shows |
|---|---|---|
| `linux/01-users-permissions.png` | `linux/01` | User and group identity (`id`) plus ownership and permissions of the shared directory and its files |
| `linux/02-httpd-service.png` | `linux/02` | `systemctl status httpd` with `active (running)` and a successful local `curl -I http://localhost` |
| `linux/04-ssh-key-login.png` | `linux/04` | Successful SSH key-based login without a password prompt, followed by `whoami` or `hostname` |
| `linux/05-troubleshooting.png` | `linux/05` | One real troubleshooting sequence: failure, investigation, fix and successful verification |

Linux lab 03 has no screenshot, and neither has any networking lab.

## Rules

1. Take the screenshot of a real terminal in the Fedora VM (or on the host for the SSH login).
2. Keep it focused on the relevant commands and output.
3. Never include passwords, private key contents, tokens, or other secrets.
4. Use PNG and keep the files reasonably small (about 300 KB or less when practical).
5. Use exactly the file names in the table above. This folder is the only place for screenshots.

In the Fedora VM, the screenshot tool saves files to `~/Pictures/Screenshots`. A screenshot from
the host (the SSH login) can be copied into the VM with `scp` or a VirtualBox shared folder.
