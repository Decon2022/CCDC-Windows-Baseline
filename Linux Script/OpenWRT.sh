#!/bin/sh
# Simple CCDC script for OpenWRT (vigra, 192.168.220.2). Run as root.
# OpenWRT has no bash by default, so this uses plain sh.
# Usage: ./openwrt_harden.sh [backup | audit | passwd | services <name>... | harden]



backup() {
  # Save the whole config so you can restore it after an attack
  mkdir -p /root/ccdc_backup
  sysupgrade -b /root/ccdc_backup/config_$(date +%H%M%S).tar.gz
  cp -r /etc/config /root/ccdc_backup/config_dir
  echo "Backup saved in /root/ccdc_backup"
}

audit() {
  OUT=/tmp/ccdc_audit_$(date +%H%M%S).txt
  {
    echo "== Host =="; cat /proc/sys/kernel/hostname; cat /etc/openwrt_release
    echo "== Interfaces =="; ip a
    echo "== Routes =="; ip route
    echo "== Open ports =="; netstat -tulnp
    echo "== Running processes =="; ps
    echo "== Services enabled at boot =="; ls /etc/rc.d/S* 2>/dev/null
    echo "== UID 0 accounts =="; awk -F: '$3==0 {print $1}' /etc/passwd
    echo "== Accounts with a shell =="; grep -vE 'nologin|false' /etc/passwd
    echo "== SSH authorized_keys =="; cat /etc/dropbear/authorized_keys /root/.ssh/authorized_keys 2>/dev/null
    echo "== Cron jobs =="; cat /etc/crontabs/* 2>/dev/null
    echo "== Startup script (rc.local) =="; cat /etc/rc.local
    echo "== Firewall config =="; uci show firewall
    echo "== Firewall rules (live) =="; iptables -S 2>/dev/null || nft list ruleset
    echo "== DHCP / DNS config =="; uci show dhcp
    echo "== Dropbear (SSH) config =="; uci show dropbear
    echo "== Web (uhttpd) config =="; uci show uhttpd
    echo "== Installed packages (user installed) =="; opkg list-installed
  } > "$OUT" 2>&1
  echo "Saved to $OUT"
}

change_password() {
  echo "Changing root password:"
  passwd root
}

stop_services() {
  for svc in "$@"; do
    /etc/init.d/$svc stop
    /etc/init.d/$svc disable
  done
}

harden() {
  # Back up first
  backup

  # Remove any SSH keys that were planted (comment this out if you use keys)
  > /etc/dropbear/authorized_keys

  # SSH: no password-less logins, listen on the LAN only
  uci set dropbear.@dropbear[0].PasswordAuth='on'
  uci set dropbear.@dropbear[0].RootPasswordAuth='on'
  uci set dropbear.@dropbear[0].Interface='lan'
  uci commit dropbear

  # Block incoming traffic from the WAN by default
  uci set firewall.@defaults[0].input='REJECT'
  uci set firewall.@defaults[0].forward='REJECT'
  uci commit firewall

  # Turn on firewall logging for dropped packets
  uci set firewall.@defaults[0].drop_invalid='1'
  uci commit firewall

  /etc/init.d/dropbear restart
  /etc/init.d/firewall restart
  echo "Done. Check that scored services still work (routing, DNS, DHCP, forwarding)."
}

case "$1" in
  backup)   backup ;;
  audit)    audit ;;
  passwd)   change_password ;;
  services) shift; stop_services "$@" ;;
  harden)   harden ;;
  *)        echo "Usage: $0 [backup | audit | passwd | services <name>... | harden]" ;;
esac
