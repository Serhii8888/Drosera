#!/bin/bash

set -e

# Основні змінні
NODE_SERVICE_NAME="drosera"
NODE_USER="$USER"

# Збір даних
read -rp "Введіть GitHub email: " GITHUB_EMAIL
read -rp "Введіть GitHub username: " GITHUB_USERNAME
read -rp "Введіть приватний ключ гаманця (приховано): " DROSERA_PRIVATE_KEY
echo
read -rp "Введіть IP вашого VPS: " VPS_IP
read -rp "Введіть публічну адресу оператора (Ethereum address): " OPERATOR_ADDRESS

# Збереження даних у тимчасовий файл для другої частини
cat > ~/drosera_vars.env <<EOF
export GITHUB_EMAIL="${GITHUB_EMAIL}"
export GITHUB_USERNAME="${GITHUB_USERNAME}"
export DROSERA_PRIVATE_KEY="${DROSERA_PRIVATE_KEY}"
export VPS_IP="${VPS_IP}"
export OPERATOR_ADDRESS="${OPERATOR_ADDRESS}"
EOF

# Встановлення всіх пакетів, Docker, Foundry, Drosera, Bun – як у твоєму коді...

# Створення Trap
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap || exit

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

forge init -t drosera-network/trap-foundry-template
bun install || true
source ~/.bashrc || true
forge build || true

echo "⚙️ Створення Trap..."
DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

echo "✅ Trap створено!"
echo "💰 Поповніть Trap ETH для покриття газу."
echo "➡️ Потім запустіть другу частину скрипта: ./drosera-part2.sh"
