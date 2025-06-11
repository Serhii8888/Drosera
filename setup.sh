#!/bin/bash
set -e

# Основні змінні
read -rp "Введіть GitHub email: " GITHUB_EMAIL
read -rp "Введіть GitHub username: " GITHUB_USERNAME
read -rp "Введіть приватний ключ гаманця (приховано): " DROSERA_PRIVATE_KEY
read -rp "Введіть публічну адресу оператора (Ethereum address): " OPERATOR_ADDRESS

# Встановлення Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
export PATH="$HOME/.foundry/bin:$PATH"
~/.foundry/bin/foundryup || true

# Встановлення Bun
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
~/.bun/bin/bun || true

# Створення Trap
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap || exit

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

forge init -t drosera-network/trap-foundry-template
bun install || true
forge build || true

# Застосування Trap
echo "⚙️ Створення Trap..."
DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

echo "✅ Trap створено!"
echo "🔗 Поповніть Trap ETH перед продовженням."
echo "📂 Після поповнення запусти наступний скрипт: ./drosera-continue.sh"

# Зберегти змінні для другого скрипта
cat > ~/my-drosera-trap/variables.env <<EOF
export DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY"
export OPERATOR_ADDRESS="$OPERATOR_ADDRESS"
EOF
