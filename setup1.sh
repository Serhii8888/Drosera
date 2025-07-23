#!/bin/bash

# ==== 0. Запит даних ====
read -p "🔐 Введіть приватний ключ Оператора (PRIVATE_KEY): " PRIVATE_KEY
read -p "🌐 Введіть публічну IP-адресу вашого VPS (VPS_IP): " VPS_IP

# ==== 1. Встановлення залежностей ====
echo "⚙️ Встановлюємо необхідні пакети..."
sudo apt-get update
sudo apt-get install -y curl clang libssl-dev tar ufw

# ==== 2. Встановлення droseraup та drosera-operator CLI ====
echo "⬇️ Встановлення droseraup та drosera-operator CLI..."
curl -L https://app.drosera.io/install | bash

# Оновлюємо PATH
source "$HOME/.bashrc"

# Встановлення останньої версії drosera-operator (наприклад, v1.20.0)
VERSION="v1.20.0"
mkdir -p "$HOME/.drosera/bin"
curl -LO "https://github.com/drosera-network/releases/releases/download/${VERSION}/drosera-operator-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"
tar -xvf "drosera-operator-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"
mv drosera-operator "$HOME/.drosera/bin/"
chmod +x "$HOME/.drosera/bin/drosera-operator"

# ==== 3. Реєстрація оператора ====
echo "📝 Реєстрація оператора..."
"$HOME/.drosera/bin/drosera-operator" register --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com --eth-private-key "$PRIVATE_KEY"

# ==== 4. Створення каталогу для бази даних ====
echo "📁 Створення каталогу для бази даних..."
sudo mkdir -p /var/lib/drosera-data
sudo chown -R root:root /var/lib/drosera-data
sudo chmod -R 700 /var/lib/drosera-data

# ==== 5. Створення systemd сервісу ====
echo "⚙️ Створення systemd сервісу..."

sudo tee /etc/systemd/system/drosera-operator.service > /dev/null <<EOF
[Unit]
Description=Service for Drosera Operator
Requires=network.target
After=network.target

[Service]
Type=simple
Restart=always

Environment="DRO__DB_FILE_PATH=/var/lib/drosera-data/drosera.db"
Environment="DRO__DROSERA_ADDRESS=0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"
Environment="DRO__LISTEN_ADDRESS=0.0.0.0"
Environment="DRO__ETH__CHAIN_ID=56048"
Environment="DRO__ETH__RPC_URL=https://ethereum-hoodi-rpc.publicnode.com"
Environment="DRO__ETH__BACKUP_RPC_URL=https://1rpc.io/hoodi"
Environment="DRO__ETH__PRIVATE_KEY=${PRIVATE_KEY}"
Environment="DRO__NETWORK__P2P_PORT=31313"
Environment="DRO__NETWORK__EXTERNAL_P2P_ADDRESS=${VPS_IP}"
Environment="DRO__SERVER__PORT=31314"

ExecStart=$HOME/.drosera/bin/drosera-operator node

[Install]
WantedBy=multi-user.target
EOF

# ==== 6. Налаштування фаєрволу ====
echo "🔓 Налаштування UFW (фаєрвол)..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
echo "y" | sudo ufw enable

# ==== 7. Запуск сервісу ====
echo "🚀 Запуск drosera-operator через systemd..."
sudo systemctl daemon-reload
sudo systemctl enable drosera-operator.service
sudo systemctl start drosera-operator.service

echo "✅ Установка та запуск завершені!"
echo "Перевірте статус сервісу командою: sudo systemctl status drosera-operator.service"
echo "Для перегляду логів використовуйте: sudo journalctl -u drosera-operator.service -f"
