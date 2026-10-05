#!/usr/bin/env bash

set -u

fails=0

title() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf '  [ OK ] %s\n' "$1"
}

fail() {
  printf '  [FAIL] %s\n' "$1"
  fails=$((fails + 1))
}

title "Interfaces (link state)"
ip -brief link

title "IP addresses"
ip -brief addr

title "Active connections (NetworkManager)"
if command -v nmcli >/dev/null 2>&1; then
  nmcli -t -f NAME,DEVICE,STATE connection show --active
else
  echo "  nmcli not found, skipping"
fi

title "Default route"
route_line=$(ip route show default | head -n 1)
if [ -n "$route_line" ]; then
  echo "  $route_line"
  gateway=$(echo "$route_line" | awk '{print $3}')
  if ping -c 2 -W 2 "$gateway" >/dev/null 2>&1; then
    pass "gateway $gateway answers ping"
  else
    fail "gateway $gateway does not answer ping"
  fi
else
  fail "no default route (this machine has no way out to other networks)"
fi

title "Internet reachability (IP level)"
if ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
  pass "1.1.1.1 answers ping — IP level is fine"
else
  fail "1.1.1.1 does not answer — problem is before DNS (link, IP, route or firewall)"
fi

title "DNS resolution"
resolved=$(getent hosts fedoraproject.org | head -n 1 | awk '{print $1}')
if [ -n "$resolved" ]; then
  pass "fedoraproject.org resolves -> $resolved"
else
  fail "fedoraproject.org does not resolve — DNS problem (see Lab 03 and Lab 05)"
fi

title "HTTPS test"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 https://fedoraproject.org || true)
case "$code" in
  200|301|302) pass "https://fedoraproject.org answered with HTTP $code" ;;
  *)           fail "https://fedoraproject.org answered with '${code:-no answer}'" ;;
esac

title "Listening TCP ports"
ss -tln | head -n 12

title "Summary"
if [ "$fails" -eq 0 ]; then
  echo "  All network checks passed."
  exit 0
else
  printf '  %s check(s) failed. Look at the [FAIL] lines above.\n' "$fails"
  exit 1
fi
