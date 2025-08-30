#!/bin/bash
set -e

# === Користувацькі дані ===
read -p "Введіть свій GitHub email: " GITHUB_EMAIL
read -p "Введіть свій GitHub username: " GITHUB_USERNAME
read -p "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY

# === Оновлення системи ===
sudo apt-get update && sudo apt-get upgrade -y

# === Базові пакети ===
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop \
nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

# === Docker ===
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" || true
done

sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world || true

# === Drosera CLI (droseraup) ===
curl -sSfL https://raw.githubusercontent.com/drosera-network/releases/main/droseraup/install | bash
echo 'export PATH=$HOME/.drosera/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.drosera/bin:$PATH
command -v droseraup >/dev/null || { echo "❌ droseraup не знайдений"; exit 1; }

# === Foundry ===
curl -L https://foundry.paradigm.xyz | bash
echo 'export PATH=$HOME/.foundry/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.foundry/bin:$PATH
foundryup
command -v forge >/dev/null || { echo "❌ forge не знайдений"; exit 1; }

# === Bun ===
curl -fsSL https://bun.sh/install | bash
echo 'export PATH=$HOME/.bun/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/.bun/bin:$PATH
command -v bun >/dev/null || { echo "❌ bun не знайдений"; exit 1; }

# === Створення проекту Trap ===
TRAP_DIR=my-drosera-trap
if [ -d "$TRAP_DIR" ]; then
    echo "⚠️ Каталог '$TRAP_DIR' вже існує. Пропускаємо створення."
else
    forge init -t drosera-network/trap-foundry-template "$TRAP_DIR"
fi

cd "$TRAP_DIR"
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# === Встановлення залежностей ===
bun install

# Ставимо правильний пакет контрактів
bun add github:drosera-network/contracts

# === Автоматичне виправлення імпортів у src/ і test/ ===
find src test -type f -name "*.sol" -print0 | while IFS= read -r -d '' file; do
  # Іменовані імпорти замість plain-import forge-std
  sed -i 's|import "forge-std/\(.*\).sol"|import {\1} from "forge-std/\1.sol"|g' "$file"
  # Замінюємо старі drosera-contracts на @drosera/contracts/src/
  sed -i 's|drosera-contracts/|@drosera/contracts/src/|g' "$file"
done

# === Компіляція ===
forge build

# === Фінальні інструкції ===
cat <<EOF

✅ Установка завершена!
ℹ️ Поповніть гаманець Hoodi ETH через faucet.

Після поповнення запустіть:

DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply

👉 Підтвердження введіть: ofc

⚠️ Після перезавантаження виконайте:
source ~/.bashrc

EOF
