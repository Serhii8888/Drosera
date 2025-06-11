#!/bin/bash

# ===== Запит змінних =====
echo "--- Налаштування Оператора Drosera ---"
read -p "Введіть whitelist-адресу (Operator Address): " OPERATOR_ADDRESS
read -p "Введіть IP вашого сервера (VPS): " VPS_IP
read -p "Введіть приватний ключ оператора (ETH private key): " OPERATOR_PRIVKEY

# ===== Створення та оновлення drosera.toml =====
cat > drosera.toml <<EOF
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

echo "✅ drosera.toml оновлено."

# ===== Застосування Trap =====
echo "\n--- Застосування Trap (drosera apply) ---"
DROSERA_PRIVATE_KEY=$OPERATOR_PRIVKEY drosera apply

# ===== Встановлення drosera-operator CLI =====
echo "\n--- Завантаження CLI drosera-operator ---"
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
chmod +x drosera-operator
sudo cp drosera-operator /usr/bin

echo "✅ drosera-operator встановлено. Версія:"
drosera-operator --version

# ===== Docker (опційно) =====
echo "\n--- Завантаження Docker-образу (опційно) ---"
docker pull ghcr.io/drosera-network/drosera-operator:latest

# ===== Реєстрація Оператора =====
echo "\n--- Реєстрація Оператора ---"
drosera-operator register \
  --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
  --eth-private-key $OPERATOR_PRIVKEY

# ===== Створення systemd сервісу =====
echo "\n--- Створення systemd сервісу ---"
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Operator Service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node \
  --db-file-path $HOME/.drosera.db \
  --network-p2p-port 31313 \
  --server-port 31314 \
  --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
  --eth-backup-rpc-url https://1rpc.io/holesky \
  --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
  --eth-private-key $OPERATOR_PRIVKEY \
  --listen-address 0.0.0.0 \
  --network-external-p2p-address $VPS_IP \
  --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# ===== Відкриття портів =====
echo "\n--- Налаштування фаєрволу ---"
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# ===== Запуск systemd =====
echo "\n--- Запуск drosera systemd ---"
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo "\n✅ Оператор Drosera встановлено та запущено!"
