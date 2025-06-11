#!/bin/bash
set -e

NODE_SERVICE_NAME="drosera"
NODE_USER="$USER"

function install_node() {
  echo "📦 Починаємо встановлення ноди Drosera..."

  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip

  echo "🐳 Встановлення Docker..."
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update -y && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo docker run hello-world || true

  read -rp "GitHub Email: " GITHUB_EMAIL
  read -rp "GitHub Username: " GITHUB_USERNAME
  read -rsp "Приватний ключ гаманця: " DROSERA_PRIVATE_KEY 
  echo
  read -rp "IP вашого VPS: " VPS_IP
  read -rp "Публічна адреса оператора (0x...): " OPERATOR_ADDRESS

  echo "📥 Встановлення Drosera CLI..."
  curl -L https://app.drosera.io/install | bash
  export PATH="$HOME/.drosera/bin:$PATH"
  source ~/.bashrc
  droseraup || true

  echo "📥 Встановлення Foundry CLI..."
  curl -L https://foundry.paradigm.xyz | bash
  export PATH="$HOME/.foundry/bin:$PATH"
  source ~/.bashrc
  foundryup || true

  echo "📥 Встановлення Bun..."
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  source ~/.bashrc
  bun --version || true

  echo "🔧 Trap: Створити чи пропустити?"
  echo "1) Створити"
  echo "2) Пропустити (вже створений)"
  read -rp "Ваш вибір (1-2): " trap_choice

  mkdir -p ~/my-drosera-trap
  cd ~/my-drosera-trap || exit

  if [[ "$trap_choice" == "1" ]]; then
    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"

    forge init -t drosera-network/trap-foundry-template
    bun install
    forge build

    echo "⚙️ Створення Trap..."
    DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

    echo "✅ Trap створено! Поповніть його ETH на Holesky."
    read -p "Натисніть Enter для продовження після поповнення..."
  else
    echo "⏭️ Пропущено створення Trap."
  fi

  if [ ! -f drosera.toml ]; then
    echo "❌ Файл drosera.toml не знайдено!"
    exit 1
  fi

  sed -i 's/private = true/private_trap = true/' drosera.toml
  if ! grep -q "whitelist" drosera.toml; then
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
  fi

  echo "📤 Повторне застосування Trap з whitelist..."
  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

  cd ~

  echo "📥 Завантаження Drosera Operator CLI..."
  curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
  tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
  sudo cp drosera-operator /usr/bin/
  rm drosera-operator*

  docker pull ghcr.io/drosera-network/drosera-operator:latest

  echo "🪪 Реєстрація оператора..."
  drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$DROSERA_PRIVATE_KEY"

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
  --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
  --eth-private-key $DROSERA_PRIVATE_KEY \
  --listen-address 0.0.0.0 \
  --network-external-p2p-address $VPS_IP \
  --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

  echo "🔥 Налаштування Firewall..."
  sudo ufw allow ssh
  sudo ufw allow 31313/tcp
  sudo ufw allow 31314/tcp
  sudo ufw --force enable

  echo "🚀 Запуск Drosera-ноди..."
  sudo systemctl daemon-reload
  sudo systemctl enable ${NODE_SERVICE_NAME}
  sudo systemctl start ${NODE_SERVICE_NAME}

  echo "✅ Успішно встановлено!"
  echo "📜 Перегляд логів: journalctl -u ${NODE_SERVICE_NAME} -f"
}

function remove_node() {
  echo "🛑 Зупинка та видалення ноди..."
  sudo systemctl stop ${NODE_SERVICE_NAME}
  sudo systemctl disable ${NODE_SERVICE_NAME}
  sudo rm -f /etc/systemd/system/${NODE_SERVICE_NAME}.service
  sudo systemctl daemon-reload

  sudo rm -f /usr/bin/drosera-operator
  rm -rf ~/my-drosera-trap
  echo "✅ Видалено."
}

function restart_node() {
  echo "🔁 Перезапуск ноди..."
  sudo systemctl restart ${NODE_SERVICE_NAME}
  echo "✅ Перезапущено."
}

function main_menu() {
  while true; do
    echo "==============================="
    echo "1) Встановити ноду"
    echo "2) Видалити ноду"
    echo "3) Перезапустити ноду"
    echo "4) Вийти"
    read -rp "Ваш вибір (1-4): " choice
    case $choice in
      1) install_node ;;
      2) remove_node ;;
      3) restart_node ;;
      4) echo "👋 До побачення!"; exit 0 ;;
      *) echo "❗ Невірний вибір!" ;;
    esac
  done
}

main_menu
