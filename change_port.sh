#!/bin/bash

# =====================================
# ONE-TIME SSH PORT CHANGER (AUTO DELETE)
# LOCKED TO PORT 2222
# =====================================

NEW_PORT=2222

echo "Changing SSH port to $NEW_PORT..."

CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%s)"
SCRIPT_PATH="$(readlink -f "$0")"

# ===== BACKUP =====
cp "$CONFIG" "$BACKUP"

# ===== UPDATE PORT =====
if grep -q "^Port " "$CONFIG"; then
    sed -i "s/^Port .*/Port $NEW_PORT/" "$CONFIG"
else
    echo "Port $NEW_PORT" >> "$CONFIG"
fi

# ===== OPEN FIREWALL PORT =====
if command -v ufw >/dev/null 2>&1; then
    ufw allow 2222/tcp >/dev/null 2>&1
fi

iptables -I INPUT -p tcp --dport 2222 -j ACCEPT 2>/dev/null

# ===== RESTART SSH =====
systemctl restart ssh 2>/dev/null || systemctl restart sshd

sleep 2

# ===== VERIFY =====
if ss -tln | grep ":2222 " >/dev/null; then
    echo ""
    echo "✅ SUCCESS!"
    echo "SSH running on port 2222"
    echo "Use: ssh root@SERVER_IP -p 2222"

    # ===== DELETE SCRIPT AFTER SUCCESS =====
    rm -f "$SCRIPT_PATH"

else
    echo "❌ FAILED — restoring backup"
    mv "$BACKUP" "$CONFIG"
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
fi
