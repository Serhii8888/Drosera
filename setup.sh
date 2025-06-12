#!/bin/bash

set -e

# Запит користувача
read -p "Введіть свій GitHub email: " GITHUB_EMAIL
read -p "Введіть свій GitHub username: " GITHUB_USERNAME
read -p "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY

# Оновлення системи
sudo apt-get update && sudo apt-get upgrade -y

# Встановлення необхідних пакетів
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y

# Видалення старих версій Docker
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

# Встановлення Docker
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Перевірка Docker
sudo docker run hello-world

# Встановлення Drosera CLI
curl -L https://app.drosera.io/install | bash

# Додавання droseraup до PATH, якщо потрібно
if ! grep -q '/root/.drosera/bin' ~/.bashrc; then
  echo 'export PATH=/root/.drosera/bin:$PATH' >> ~/.bashrc
fi
export PATH=/root/.drosera/bin:$PATH

# Перезапуск PATH для доступу до droseraup
source ~/.bashrc

# Перевірка droseraup
if ! command -v droseraup &> /dev/null; then
  echo "❌ droseraup не знайдений. Перевірте встановлення вручну."
  exit 1
fi

droseraup

# Встановлення Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc

# Додавання foundry до PATH
if ! grep -q '.foundry/bin' ~/.bashrc; then
  echo 'export PATH=$HOME/.foundry/bin:$PATH' >> ~/.bashrc
fi
export PATH=$HOME/.foundry/bin:$PATH

foundryup

# Перевірка forge
if ! command -v forge &> /dev/null; then
  echo "❌ forge не знайдений. Перевірте встановлення Foundry вручну."
  exit 1
fi

# Встановлення Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Додавання bun до PATH
if ! grep -q '.bun/bin' ~/.bashrc; then
  echo 'export PATH=$HOME/.bun/bin:$PATH' >> ~/.bashrc
fi
export PATH=$HOME/.bun/bin:$PATH

# Перевірка bun
if ! command -v bun &> /dev/null; then
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
echo ""
echo "✅ Установка завершена!"
echo "ℹ️ Тепер потрібно поповнити гаманець Holesky ETH через faucet."
echo ""
echo "Після поповнення запустіть наступну команду:"
echo ""
echo "DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply"
echo ""
echo "👉 Коли попросять підтвердження — введіть: ofc"
