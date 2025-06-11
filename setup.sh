#!/bin/bash

# Запит користувача
read -p "Введіть свій GitHub email: " GITHUB_EMAIL
read -p "Введіть свій GitHub username: " GITHUB_USERNAME
read -p "Введіть приватний ключ (PRIVATE_KEY) для drosera: " DROSERA_PRIVATE_KEY

# Оновлення системи
sudo apt-get update && sudo apt-get upgrade -y

# Встановлення необхідних пакетів
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# Видалення старих версій Docker (якщо є)
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

# Додаємо Drosera до PATH
echo 'export PATH=/root/.drosera/bin:$PATH' >> /root/.bashrc
source /root/.bashrc

# Drosera оновлення
droseraup

# Встановлення Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Встановлення Bun
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Ініціалізація Trap
mkdir my-drosera-trap && cd my-drosera-trap
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

forge init -t drosera-network/trap-foundry-template

bun install
source ~/.bashrc
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
