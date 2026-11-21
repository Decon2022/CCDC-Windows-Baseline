#!/bin/bash
# Simple CCDC Linux script. Run with sudo.
# Usage: sudo ./ccdc_linux.sh [audit | passwd | auditd | services <name>...]

if [ "$EUID" -ne 0 ]; then
  echo "Run with sudo"; exit 1
fi

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
    echo "== Cron =="; cat /etc/crontab; ls /etc/cron.d /var/spool/cron* 2>/dev/null
    echo "== Timers =="; systemctl list-timers --no-pager
    echo "== SSH authorized_keys =="; cat /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys 2>/dev/null
    echo "== SUID files =="; find / -xdev -perm -4000 -type f 2>/dev/null
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
  if command -v dnf >/dev/null; then
    dnf install -y audit
  else
    apt install -y auditd
  fi
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
-w /usr/bin/sudo -p x -k sudo_execution
EOF

  augenrules --load
  auditctl -s | grep enabled
  auditctl -l
}

stop_services() {
  for svc in "$@"; do
    systemctl disable --now "$svc"
    systemctl mask "$svc"
  done
}

case "$1" in
  audit)    audit ;;
  passwd)   change_passwords ;;
  auditd)   setup_auditd ;;
  services) shift; stop_services "$@" ;;
  *)        echo "Usage: sudo $0 [audit | passwd | auditd | services <name>...]" ;;
esac