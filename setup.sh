#!/bin/bash

set -e

echo "📦 Створення Drosera Node через Docker..."

# === Вхідні дані ===
read -p "🔐 Введи приватний ключ (0x...): " PRIVATE_KEY
read -p "🌐 Введи основний Ethereum RPC (Sepolia) [натисни Enter для стандартного https://rpc.sepolia.org]: " RPC
read -p "🌐 Введи резервний Ethereum RPC [натисни Enter для стандартного https://rpc2.sepolia.org]: " BACKUP_RPC

RPC=${RPC:-https://rpc.sepolia.org}
BACKUP_RPC=${BACKUP_RPC:-https://rpc2.sepolia.org}

EXTERNAL_IP=$(curl -s ifconfig.me)
P2P_ADDRESS="${EXTERNAL_IP}:63000"

mkdir -p drosera-docker && cd drosera-docker

cat > .env <<EOF
DRO__ETH__PRIVATE_KEY=${PRIVATE_KEY}
EOF

cat > drosera.toml <<EOF
db_file_path = "./data/drosera.db"

[eth]
rpc_url = "${RPC}"
backup_rpc_url = "${BACKUP_RPC}"

[network]
external_p2p_address = "${P2P_ADDRESS}"
EOF

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  drosera:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./drosera.toml:/app/drosera.toml
      - ./data:/app/data
    command: node

EOF

docker compose up -d

echo -e "\n✅ Drosera Node запущено у Docker!"
echo "📄 Логи: docker logs -f drosera-node"
