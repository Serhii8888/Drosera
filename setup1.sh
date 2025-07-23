#!/bin/bash

# ==== 0. Запит даних ====
read -p "🔐 Введіть приватний ключ Оператора (PRIVATE_KEY): " PRIVATE_KEY
read -p "🌐 Введіть IP-адресу вашого VPS (VPS_IP): " VPS_IP

# ==== 1. Установка CLI Оператора ====
cd ~ || exit

echo "⬇️ Завантаження drosera-operator..."
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

echo "📦 Розпакування архіву..."
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

echo "🧪 Перевірка версії drosera-operator:"
./drosera-operator --version

echo "📤 Копіюємо drosera-operator у /usr/bin..."
sudo cp drosera-operator /usr/bin

echo "🔍 Перевірка команди drosera-operator:"
drosera-operator

# ==== 2. Завантаження Docker образу (опційно) ====
echo "🐳 Завантаження Docker образу (опційно)..."
docker pull ghcr.io/drosera-network/drosera-operator:latest

# ==== 3. Реєстрація Оператора з підтвердженням ====
while true; do
    echo "📝 Реєстрація оператора..."
    drosera-operator register --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com --eth-private-key "$PRIVATE_KEY"

    echo ""
    read -p "✅ Продовжити далі? (y/n): " CONTINUE
    if [[ "$CONTINUE" == "y" || "$CONTINUE" == "Y" ]]; then
        break
    fi
    echo "🔁 Повторна спроба реєстрації..."
done

# ==== 4. Створення systemd-сервісу ====
echo "⚙️ Створення systemd сервісу..."
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-hoodi-rpc.publicnode.com \
    --eth-backup-rpc-url https://relay.hoodi.drosera.io \
    --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
    --eth-private-key $PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# ==== 5. Додати PATH до .bashrc ====
echo "📌 Додаємо drosera до PATH..."
echo 'export PATH=/root/.drosera/bin:$PATH' >> /root/.bashrc
source /root/.bashrc

# ==== 6. Відкриття портів ====
echo "🔓 Налаштування UFW (фаєрвол)..."
sudo ufw allow ssh
sudo ufw allow 22
echo "y" | sudo ufw enable

# Allow Drosera ports
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp

# ==== 7. Запуск Оператора ====
echo "🚀 Запуск drosera-operator через systemd..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo "✅ Установка завершена!"
