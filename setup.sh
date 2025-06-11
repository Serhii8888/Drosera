#!/bin/bash

set -e

NODE_SERVICE_NAME="drosera"
NODE_USER="$USER"

function install_node() {
  echo "Починаємо встановлення ноди..."

  sudo apt-get update && sudo apt-get upgrade -y

  sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

  echo "Встановлення Docker..."
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update -y && sudo apt upgrade -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  echo "Перевірка установки Docker..."
  sudo docker run hello-world || true

  # Запит даних
  read -rp "Введіть GitHub email: " GITHUB_EMAIL
  read -rp "Введіть GitHub username: " GITHUB_USERNAME
  read -rsp "Введіть приватний ключ гаманця (приховано): " DROSERA_PRIVATE_KEY
  echo
  read -rp "Введіть IP вашого VPS: " VPS_IP
  read -rp "Введіть публічну адресу оператора (Ethereum address): " OPERATOR_ADDRESS

  echo "Встановлення Drosera CLI..."
  curl -L https://app.drosera.io/install | bash
  ~/.drosera/bin/droseraup || true

  echo "Встановлення Foundry CLI..."
  curl -L https://foundry.paradigm.xyz | bash
  ~/.foundry/bin/foundryup || true


  echo "Встановлення Bun..."
  curl -fsSL https://bun.sh/install | bash
  ~/.bun/bin/bun || true


  mkdir -p ~/my-drosera-trap
  cd ~/my-drosera-trap || exit

  git config --global user.email "$GITHUB_EMAIL"
  git config --global user.name "$GITHUB_USERNAME"

  forge init -t drosera-network/trap-foundry-template

  bun install || true
  source ~/.bashrc || true
  forge build || true

  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

  # Налаштування drosera.toml
  if [ ! -f drosera.toml ]; then
    echo "Файл drosera.toml не знайдено! Перевірте виконання попередніх кроків."
    exit 1
  fi

  sed -i 's/private = true/private_trap = true/' drosera.toml

  if ! grep -q "whitelist" drosera.toml; then
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
  fi

  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

  cd ~ || exit

  echo "Завантаження drosera-operator CLI..."
  curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
  tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

  sudo cp drosera-operator /usr/bin/
  rm drosera-operator drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

  docker pull ghcr.io/drosera-network/drosera-operator:latest || true

  ./drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$DROSERA_PRIVATE_KEY"

  sudo tee /etc/systemd/system/${NODE_SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network-online.target

[Service]
User=${NODE_USER}
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $DROSERA_PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

  sudo ufw allow ssh
  sudo ufw allow 22
  sudo ufw allow 31313/tcp
  sudo ufw allow 31314/tcp
  sudo ufw --force enable

  sudo systemctl daemon-reload
  sudo systemctl enable ${NODE_SERVICE_NAME}
  sudo systemctl start ${NODE_SERVICE_NAME}

  echo "Встановлення завершено!"
  echo "Логи ноди дивіться через:"
  echo "journalctl -u ${NODE_SERVICE_NAME} -f"
}

function remove_node() {
  echo "Зупинка і видалення ноди..."
  sudo systemctl stop ${NODE_SERVICE_NAME} || true
  sudo systemctl disable ${NODE_SERVICE_NAME} || true
  sudo rm /etc/systemd/system/${NODE_SERVICE_NAME}.service || true
  sudo systemctl daemon-reload

  echo "Видалення drosera-operator..."
  sudo rm /usr/bin/drosera-operator || true

  echo "Видалення робочих файлів..."
  rm -rf ~/my-drosera-trap
  rm -f drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

  echo "Видалення завершено."
}

function restart_node() {
  echo "Перезапуск ноди..."
  sudo systemctl restart ${NODE_SERVICE_NAME}
  echo "Нода перезапущена."
}

function main_menu() {
  while true; do
    echo "-------------------------------"
    echo "Виберіть дію:"
    echo "1) Встановити ноду"
    echo "2) Видалити ноду"
    echo "3) Перезапустити ноду"
    echo "4) Вийти"
    echo -n "Ваш вибір (1-4): "
    read choice
    case $choice in
      1) install_node ;;
      2) remove_node ;;
      3) restart_node ;;
      4) echo "Вихід."; exit 0 ;;
      *) echo "Невірний вибір, спробуйте ще раз." ;;
    esac
  done
}

main_menu
