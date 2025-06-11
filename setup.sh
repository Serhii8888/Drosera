#!/bin/bash

# --- КОЛЬОРИ ---
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Drosera Node Installer ---${NC}"

# --- ВВЕДЕННЯ ЗМІННИХ ---
read -p "Введіть ваш GitHub email: " GITHUB_EMAIL
read -p "Введіть ваш GitHub username: " GITHUB_USERNAME
read -p "Введіть приватний ключ гаманця (для Trap та Оператора): " PRIVATE_KEY
read -p "Введіть публічну адресу гаманця (для whitelist): " PUBLIC_ADDRESS
read -p "Введіть публічний IP вашого сервера: " VPS_IP

# --- ОНОВЛЕННЯ СИСТЕМИ ---
sudo apt-get update && sudo apt-get upgrade -y

# --- УСТАНОВКА ПАКЕТІВ ---
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# --- ВСТАНОВЛЕННЯ DOCKER ---
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# --- ТЕСТ DOCKER ---
sudo docker run hello-world

# --- ВСТАНОВЛЕННЯ CLI ---
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# --- СТВОРЕННЯ ТРАПА ---
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
forge init -t drosera-network/trap-foundry-template

bun install
forge build

# --- APPLY TRAP ---
export DROSERA_PRIVATE_KEY=$PRIVATE_KEY
drosera apply <<< "ofc"

# --- КОНФІГУРАЦІЯ drosera.toml ---
sed -i 's/private = true/private_trap = true/' drosera.toml
echo "whitelist = [\"$PUBLIC_ADDRESS\"]" >> drosera.toml

drosera apply <<< "ofc"

# --- ВСТАНОВЛЕННЯ ОПЕРАТОРА ---
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin

# --- РЕЄСТРАЦІЯ ОПЕРАТОРА ---
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIVATE_KEY

# --- СТВОРЕННЯ SYSTEMD ---
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# --- ВІДКРИТТЯ ПОРТІВ ---
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# --- ЗАПУСК СЕРВІСУ ---
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo -e "${GREEN}Установка завершена! Перейдіть в https://app.drosera.io/ для активації Trap та Opt-in оператора.${NC}"
echo -e "Перевірка логів: ${GREEN}journalctl -u drosera.service -f${NC}"
