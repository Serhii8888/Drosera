#!/bin/bash

# --- Збір змінних ---
echo "⚙️  Налаштування Drosera Оператора..."
read -p "Введіть публічну адресу оператора (для whitelist): " OPERATOR_ADDRESS
read -p "Введіть приватний ключ оператора: " OPERATOR_PRIVATE_KEY
read -p "Введіть IP-адресу вашого сервера (VPS_IP): " VPS_IP

# --- Створення файлу конфігурації drosera.toml ---
cat <<EOF > drosera.toml
ethereum_rpc = "https://ethereum-holesky-rpc.publicnode.com"
drosera_rpc = "https://relay.testnet.drosera.io"
eth_chain_id = 17000
drosera_address = "0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0xdA890040Af0533D98B9F5f8FE3537720ABf83B0C"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 5
private_trap = true
whitelist = ["$OPERATOR_ADDRESS"]
address = "0x6178Cb6392bE1e2fC61b62054685Ce4E40a08472"

[network]
external_p2p_address = "/ip4/$VPS_IP/tcp/31313"
listen_port = 31313
EOF

# --- Підтвердження Trap ---
echo "\n⚙️  Оновлюємо Trap конфігурацію..."
DROSERA_PRIVATE_KEY=$OPERATOR_PRIVATE_KEY drosera apply

# --- Встановлення CLI Оператора ---
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
chmod +x drosera-operator
sudo cp drosera-operator /usr/bin

echo "\n✅ drosera-operator встановлено. Перевірка версії:"
drosera-operator --version

# --- Docker образ (опціонально) ---
docker pull ghcr.io/drosera-network/drosera-operator:latest

# --- Реєстрація Оператора ---
drosera-operator register \
  --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
  --eth-private-key $OPERATOR_PRIVATE_KEY

# --- Створення systemd-сервісу ---
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path \$HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $OPERATOR_PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# --- Відкриття портів ---
echo "\n⚙️  Відкриваємо порти..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw enable

# --- Запуск systemd-сервісу ---
echo "\n🚀 Запуск drosera оператора..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# --- Завершення ---
echo "\n✅ Готово! Оператор Drosera запущений. Перевірити статус можна командою:"
echo "sudo systemctl status drosera"
