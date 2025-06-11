#!/bin/bash

set -e

NODE_SERVICE_NAME="drosera"
NODE_USER="$USER"
RPC_URL="https://holesky.drpc.org"

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
  export PATH="$HOME/.drosera/bin:$PATH"
  ~/.drosera/bin/droseraup || true

  echo "Встановлення Foundry CLI..."
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  ~/.foundry/bin/foundryup || true

  echo "Встановлення Bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  ~/.bun/bin/bun || true

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

  # Отримати адресу трапу з файлу (якщо такого немає, попросити ввести вручну)
  TRAP_ADDRESS=$(jq -r '.trap.address' trap_output.json 2>/dev/null || echo "")

  if [ -z "$TRAP_ADDRESS" ] || [ "$TRAP_ADDRESS" = "null" ]; then
    echo "Не вдалося отримати адресу трапу з trap_output.json, введіть її вручну:"
    read -rp "Адреса трапу: " TRAP_ADDRESS
  fi

  echo "⏳ Очікуємо появи контракту за адресою $TRAP_ADDRESS ..."

  until curl -s -X POST \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["'"$TRAP_ADDRESS"',"latest"],"id":1}' \
    "$RPC_URL" | grep -qv '"result":"0x"'; do
      echo "⏳ Контракт ще не розгорнуто... чекаємо 5 секунд"
      sleep 5
  done

  echo "✅ Контракт трапу розгорнуто!"

  echo "Зачекайте, поки він з'явиться на Etherscan, та поповніть його ETH для оплати газу."
  echo "🔗 Explorer Link: https://holesky.etherscan.io/address/$TRAP_ADDRESS"
  read -p "Натисніть Enter, коли Trap поповнено і можна продовжити..."

  # Налаштування drosera.toml
  if [ ! -f drosera.toml ]; then
    echo "Файл drosera.toml не знайдено! Перевірте виконання попередніх кроків."
    exit 1
  fi

  sed -i 's/private = true/private_trap = true/' drosera.toml

  if ! grep -q "whitelist" drosera.toml; then
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
  fi

  echo "📦 Повторне застосування конфігурації з whitelist..."
  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

  cd ~ || exit

  echo "📥 Завантаження drosera-operator CLI..."
  curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
  tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
  sudo cp drosera-operator /usr/bin/
  rm drosera-operator drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

  docker pull ghcr.io/drosera-network/drosera-operator:latest || true

  echo "📡 Реєстрація оператора..."
  ./drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$DROSERA_PRIVATE_KEY"

  echo "🛠️ Створення systemd-сервісу..."
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
    --drosera-address $TRAP_ADDRESS \
    --eth-private-key $DROSERA_PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

  echo "🔐 Налаштування firewall..."
  sudo ufw allow ssh
  sudo ufw allow 22
  sudo ufw allow 31313/tcp
  sudo ufw allow 31314/tcp
  sudo ufw --force enable

  echo "🚀 Запуск ноди..."
  sudo systemctl daemon-reload
  sudo systemctl enable ${NODE_SERVICE_NAME}
  sudo systemctl start ${NODE_SERVICE_NAME}

  echo "✅ Встановлення завершено!"
  echo "📄 Перевірити логи: journalctl -u ${NODE_SERVICE_NAME} -f"
}

function remove_node() {
  echo "⛔ Зупинка і видалення ноди..."
  sudo systemctl stop ${NODE_SERVICE_NAME} || true
  sudo systemctl disable ${NODE_SERVICE_NAME} || true
  sudo rm /etc/systemd/system/${NODE_SERVICE_NAME}.service || true
  sudo systemctl daemon-reload

  echo "🧹 Видалення drosera-operator..."
  sudo rm /usr/bin/drosera-operator || true

  echo "🧹 Видалення робочих файлів..."
  rm -rf ~/my-drosera-trap
  rm -f drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz

  echo "✅ Видалення завершено."
}

function restart_node() {
  echo "🔁 Перезапуск ноди..."
  sudo systemctl restart ${NODE_SERVICE_NAME}
  echo "✅ Нода перезапущена."
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
      4) echo "👋 Вихід."; exit 0 ;;
      *) echo "❌ Невірний вибір, спробуйте ще раз." ;;
    esac
  done
}

main_menu
