#!/bin/bash

set -e

# Запит користувача
read -p "Введіть свій GitHub email: " GITHUB_EMAIL
read -p "Введіть свій GitHub username: " GITHUB_USERNAME
read -p "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY

# Оновлення системи
sudo apt-get update && sudo apt-get upgrade -y

# Встановлення необхідних пакетів
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

# Видалення старих версій Docker
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" || true
done

# Встановлення Docker
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Перевірка Docker
sudo docker run hello-world

# Встановлення droseraup (інсталятор drosera)
curl -sSfL https://raw.githubusercontent.com/drosera-network/releases/main/droseraup/install | bash

# Додавання droseraup у PATH (для поточної сесії і в ~/.bashrc)
DROSERA_BIN="$HOME/.drosera/bin"
if ! echo "$PATH" | grep -q "$DROSERA_BIN"; then
  echo "export PATH=\"$DROSERA_BIN:\$PATH\"" >> "$HOME/.bashrc"
  export PATH="$DROSERA_BIN:$PATH"
fi

# Перевірка droseraup
if ! command -v droseraup &>/dev/null; then
  echo "❌ droseraup не знайдений. Перевірте встановлення вручну."
  exit 1
fi

droseraup

# Встановлення Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
if ! echo "$PATH" | grep -q "$HOME/.foundry/bin"; then
  echo "export PATH=\"$HOME/.foundry/bin:\$PATH\"" >> "$HOME/.bashrc"
  export PATH="$HOME/.foundry/bin:$PATH"
fi
foundryup

# Перевірка forge
if ! command -v forge &>/dev/null; then
  echo "❌ forge не знайдений. Перевірте встановлення Foundry вручну."
  exit 1
fi

# Встановлення Bun
curl -fsSL https://bun.sh/install | bash
if ! echo "$PATH" | grep -q "$HOME/.bun/bin"; then
  echo "export PATH=\"$HOME/.bun/bin:\$PATH\"" >> "$HOME/.bashrc"
  export PATH="$HOME/.bun/bin:$PATH"
fi

# Перевірка bun
if ! command -v bun &>/dev/null; then
  echo "❌ bun не знайдений. Перевірте встановлення вручну."
  exit 1
fi

# Ініціалізація Trap
TRAP_DIR=my-drosera-trap
if [ -d "$TRAP_DIR" ]; then
  echo "⚠️ Каталог '$TRAP_DIR' вже існує. Пропускаємо створення."
else
  mkdir "$TRAP_DIR"
fi

cd "$TRAP_DIR"
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# Ініціалізація проекту
forge init -t drosera-network/trap-foundry-template

# Встановлення залежностей
bun install
forge build

# Фінальні інструкції
cat <<EOF

✅ Установка завершена!
ℹ️ Тепер потрібно поповнити гаманець Holesky ETH через faucet.

Після поповнення запустіть наступну команду:

DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply

👉 Коли попросять підтвердження — введіть: ofc

⚠️ Увага! Щоб команди drosera, forge та bun працювали після перезавантаження — перезапустіть сесію або виконайте:

echo 'export PATH=$HOME/.drosera/bin:\$PATH' >> ~/.bashrc
echo 'export PATH=$HOME/.foundry/bin:\$PATH' >> ~/.bashrc
echo 'export PATH=$HOME/.bun/bin:\$PATH' >> ~/.bashrc
source ~/.bashrc

EOF
