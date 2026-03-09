#!/bin/bash

# =====================================
# SSH PORT CHANGER (LOCKED TO 2222)
# AUTO RUN AFTER REBOOT
# =====================================

NEW_PORT=2222

echo "Changing SSH port to $NEW_PORT..."

CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak.$(date +%s)"
SCRIPT_PATH="/usr/local/bin/change_ssh_port.sh"
SERVICE_FILE="/etc/systemd/system/change-ssh-port.service"

# ===== COPY SCRIPT TO PERMANENT LOCATION =====
if [ "$0" != "$SCRIPT_PATH" ]; then
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
fi

# ===== BACKUP CONFIG =====
cp "$CONFIG" "$BACKUP"

# ===== UPDATE PORT =====
if grep -q "^Port " "$CONFIG"; then
    sed -i "s/^Port .*/Port $NEW_PORT/" "$CONFIG"
else
    echo "Port $NEW_PORT" >> "$CONFIG"
fi

# ===== FIREWALL RULES =====
if command -v ufw >/dev/null 2>&1; then
    ufw allow 2222/tcp >/dev/null 2>&1
fi

iptables -I INPUT -p tcp --dport 2222 -j ACCEPT 2>/dev/null

# ===== RESTART SSH =====
systemctl restart ssh 2>/dev/null || systemctl restart sshd

sleep 2

# ===== VERIFY =====
if ss -tln | grep ":2222 " >/dev/null; then
    echo "✅ SSH now running on port 2222"
else
    echo "❌ FAILED — restoring backup"
    mv "$BACKUP" "$CONFIG"
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
    exit 1
fi

# ===== CREATE SYSTEMD SERVICE =====
if [ ! -f "$SERVICE_FILE" ]; then
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Force SSH Port 2222
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable change-ssh-port.service
fi

echo "✅ Script installed to run automatically after reboot"
echo "Connect using: ssh root@SERVER_IP -p 2222"
