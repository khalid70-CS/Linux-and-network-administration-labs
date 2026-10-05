#!/usr/bin/env bash

set -u

warnings=0

title() {
  printf '\n== %s ==\n' "$1"
}

warn() {
  printf '  [WARN] %s\n' "$1"
  warnings=$((warnings + 1))
}

title "Basic system information"
. /etc/os-release
printf '  Hostname : %s\n' "$(hostname)"
printf '  OS       : %s\n' "$PRETTY_NAME"
printf '  Kernel   : %s\n' "$(uname -r)"
printf '  Uptime   : %s\n' "$(uptime -p)"
printf '  Load     : %s   (1, 5 and 15 minute load average)\n' "$(cut -d' ' -f1-3 /proc/loadavg)"

title "Memory"
free -h | sed -n '1,2p'
mem_used=$(free | awk '/^Mem:/ {printf "%.0f", ($2 - $7) / $2 * 100}')
printf '  Used     : %s%% of RAM\n' "${mem_used:-?}"
if [ -n "$mem_used" ] && [ "$mem_used" -ge 90 ]; then
  warn "memory usage is very high (${mem_used}%)"
fi

title "Disk usage"
for mount in / /home; do
  percent=$(df --output=pcent "$mount" 2>/dev/null | tail -n 1 | tr -d ' %')
  printf '  %-5s : %s%% used\n' "$mount" "${percent:-?}"
  if [ -n "$percent" ] && [ "$percent" -ge 80 ]; then
    warn "$mount is ${percent}% full"
  fi
done

title "Important services"
for service in sshd firewalld NetworkManager; do
  state=$(systemctl is-active "$service" 2>/dev/null)
  printf '  %-14s : %s\n' "$service" "$state"
  if [ "$state" != "active" ]; then
    warn "$service is not running"
  fi
done

failed=$(systemctl --failed --no-legend --plain | wc -l)
printf '  Failed units   : %s\n' "$failed"
if [ "$failed" -gt 0 ]; then
  warn "there are failed units (look at them with: systemctl --failed)"
fi

title "Top 5 processes by memory"
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6

title "Summary"
if [ "$warnings" -eq 0 ]; then
  echo "  All checks passed."
  exit 0
else
  printf '  %s warning(s) found. Look at the [WARN] lines above.\n' "$warnings"
  exit 1
fi
