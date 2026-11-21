#!/bin/bash
# Simple CCDC script for Linux Mint 22.3 (djupi, 192.168.220.222, Point of Sale). Run with sudo.
# Usage: sudo ./mint_harden.sh [backup | audit | passwd | auditd | firewall <port>... | services <name>... | harden]

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo"; exit 1
fi

backup() {
  DIR=/var/tmp/.ccdc_backup_$(date +%H%M%S)
  mkdir -p "$DIR"
  tar -czpf "$DIR/etc.tar.gz" /etc
  tar -czpf "$DIR/opt_var.tar.gz" /opt /var/www /var/lib/mysql 2>/dev/null
  cp -r /var/spool/cron "$DIR/cron" 2>/dev/null
  echo "Backup saved in $DIR"
}

audit() {
  OUT=/var/tmp/.ccdc_audit_$(hostname)_$(date +%H%M%S).txt
  {
    echo "== Host =="; hostname; cat /etc/os-release
    echo "== IPs =="; ip a
    echo "== Open ports =="; ss -tulnp
    echo "== Running services =="; systemctl --type=service --state=running --no-pager
    echo "== Process tree =="; ps auxf
    echo "== UID 0 accounts =="; awk -F: '$3==0 {print $1}' /etc/passwd
    echo "== Users with a shell =="; getent passwd | grep -vE 'nologin|false'
    echo "== Recent logins =="; last -n 20
    echo "== Logged in now =="; who
    echo "== Sudoers =="; cat /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v '^#'
    echo "== Sudo group =="; getent group sudo
    echo "== Cron =="; cat /etc/crontab; ls /etc/cron.d /var/spool/cron/crontabs 2>/dev/null
    echo "== Timers =="; systemctl list-timers --no-pager
    echo "== SSH authorized_keys =="; cat /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys 2>/dev/null
    echo "== Autostart apps =="; ls /etc/xdg/autostart /home/*/.config/autostart 2>/dev/null
    echo "== SUID files =="; find / -xdev -perm -4000 -type f 2>/dev/null
    echo "== Firewall =="; ufw status verbose
    echo "== Docker =="; docker ps 2>/dev/null
  } > "$OUT" 2>&1
  echo "Saved to $OUT"
}

change_passwords() {
  for user in root $(awk -F: '$3>=1000 && $7!~/nologin|false/ {print $1}' /etc/passwd); do
    read -p "Change password for $user? (y/n) " answer
    if [ "$answer" = "y" ]; then
      passwd "$user"
    fi
  done
}

setup_auditd() {
  apt install -y auditd
  systemctl enable auditd
  service auditd start

  cat > /etc/audit/rules.d/50-security.rules <<'EOF'
-w /etc/passwd -p wa -k account_changes
-w /etc/shadow -p wa -k account_changes
-w /etc/group -p wa -k account_changes
-w /etc/ssh/sshd_config -p wa -k ssh_changes
-w /etc/sudoers -p wa -k privilege_changes
-w /etc/sudoers.d/ -p wa -k privilege_changes
-w /etc/crontab -p wa -k persistence_changes
-w /etc/cron.d/ -p wa -k persistence_changes
-w /var/spool/cron/ -p wa -k persistence_changes
-w /etc/systemd/system/ -p wa -k persistence_changes
-w /etc/xdg/autostart/ -p wa -k persistence_changes
-w /usr/bin/sudo -p x -k sudo_execution
EOF

  augenrules --load
  auditctl -s | grep enabled
  auditctl -l
}

setup_firewall() {
  # Pass the ports the POS needs, for example: firewall 22 80 443
  if [ "$#" -eq 0 ]; then
    echo "Give the scored/needed ports, e.g. $0 firewall 22 80"; exit 1
  fi
  apt install -y ufw
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  for port in "$@"; do
    ufw allow "$port"
  done
  ufw --force enable
  ufw status verbose
}

stop_services() {
  for svc in "$@"; do
    systemctl disable --now "$svc"
    systemctl mask "$svc"
  done
}

harden() {
  backup

  # SSH: no root login
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null

  # Disable guest login on the Mint login screen
  mkdir -p /etc/lightdm/lightdm.conf.d
  printf '[Seat:*]\nallow-guest=false\n' > /etc/lightdm/lightdm.conf.d/50-no-guest.conf

  # Stop services a POS machine normally does not need
  for svc in cups cups-browsed avahi-daemon bluetooth ModemManager; do
    systemctl disable --now "$svc" 2>/dev/null
  done

  echo "Done. Check that the POS service is still working."
}

case "$1" in
  backup)   backup ;;
  audit)    audit ;;
  passwd)   change_passwords ;;
  auditd)   setup_auditd ;;
  firewall) shift; setup_firewall "$@" ;;
  services) shift; stop_services "$@" ;;
  harden)   harden ;;
  *)        echo "Usage: sudo $0 [backup | audit | passwd | auditd | firewall <port>... | services <name>... | harden]" ;;
esac