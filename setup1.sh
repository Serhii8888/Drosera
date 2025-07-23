#!/bin/bash

# === 0. Запит даних ===
read -p "🔐 Введіть приватний ключ Оператора (PRIVATE_KEY): " PRIVATE_KEY
read -p "🌐 Введіть публічну IP-адресу вашого VPS (VPS_IP): " VPS_IP

# === 1. Установка CLI Оператора ===
cd ~ || exit

echo "⬇️ Завантаження drosera-operator..."
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

echo "📦 Розпакування архіву..."
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

echo "📤 Копіюємо drosera-operator у /usr/bin..."
sudo cp drosera-operator /usr/bin

echo "🧪 Перевірка версії drosera-operator:"
drosera-operator --version

# === 2. (Опційно) Завантаження Docker образу для резервного запуску ===
echo "🐳 Завантаження Docker образу drosera-operator..."
docker pull ghcr.io/drosera-network/drosera-operator:latest

# === 3. Реєстрація Оператора ===
echo "📝 Реєстрація Оператора у мережі Hoobi..."
while true; do
    drosera-operator register \
      --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
      --eth-private-key "$PRIVATE_KEY" \
      --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D

    echo ""
    read -p "✅ Продовжити запуск ноди? (y/n): " CONTINUE
    if [[ "$CONTINUE" =~ ^[Yy]$ ]]; then
        break
    fi
    echo "🔁 Повторна спроба реєстрації..."
done

# === 4. Створення systemd сервісу ===
echo "⚙️ Створення systemd сервісу для автозапуску Drosera..."
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Operator Node
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
Environment="DRO__ETH__PRIVATE_KEY=$PRIVATE_KEY"
ExecStart=$(which drosera-operator) node \
    --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
    --eth-backup-rpc-url https://relay.hoodi.drosera.io \
    --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --network-p2p-port 31313 \
    --server-port 31314 \
    --db-file-path $HOME/.drosera.db

[Install]
WantedBy=multi-user.target
EOF

# === 5. Відкриття портів ===
echo "🔓 Відкриття портів у фаєрволі..."
sudo ufw allow 22/tcp
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# === 6. Запуск сервісу Drosera ===
echo "🚀 Запуск Drosera Operator через systemd..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo "✅ Установка та запуск Drosera Operator завершені!"
echo "📊 Перевірити статус можна командою: sudo systemctl status drosera"
