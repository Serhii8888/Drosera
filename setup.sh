#!/bin/bash

NODE_DIR="$HOME/drosera-node"
SERVICE_FILE="/etc/systemd/system/drosera.service"

function remove_node() {
  echo "=== Видалення Drosera ==="
  echo "Зупинка сервісу..."
  sudo systemctl stop drosera.service 2>/dev/null || true
  echo "Вимикання автозапуску..."
  sudo systemctl disable drosera.service 2>/dev/null || true
  echo "Видалення сервісу..."
  sudo rm -f $SERVICE_FILE
  echo "Видалення CLI, конфігів і файлів..."
  rm -rf "$NODE_DIR"
  echo "Видалення завершено."
}

function install_docker() {
  echo "=== Встановлення Docker ==="
  sudo apt-get remove -y docker docker-engine docker.io containerd runc containerd.io || true
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
}

function install_node() {
  echo "=== Встановлення Drosera ==="

  # Оновлення системи та встановлення потрібних пакетів
  sudo apt-get update
  sudo apt-get install -y curl git build-essential pkg-config libssl-dev jq ufw

  # Встановлюємо Docker (офіційний спосіб, щоб уникнути конфліктів)
  install_docker

  # Встановлення bun (якщо треба)
  if ! command -v bun &> /dev/null; then
    echo "Встановлення bun..."
    curl -fsSL https://bun.sh/install | bash
    source "$HOME/.bashrc"
  fi

  # Створення каталогу ноди
  mkdir -p "$NODE_DIR"
  cd "$NODE_DIR" || exit

  # Завантаження drosera CLI (приклад, заміни на актуальний URL)
  echo "Завантаження drosera CLI..."
  curl -L -o drosera https://github.com/drosera-operator/releases/latest/download/drosera-linux-amd64
  chmod +x drosera

  # Ініціалізація та конфігурація ноди
  ./drosera init || true

  # Тут можна додати налаштування drosera.toml, якщо треба

  # Створення systemd-сервісу
  echo "[Unit]
Description=Drosera Node Service
After=network.target docker.service
Requires=docker.service

[Service]
User=$USER
WorkingDirectory=$NODE_DIR
ExecStart=$NODE_DIR/drosera start
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
" | sudo tee $SERVICE_FILE

  sudo systemctl daemon-reload
  sudo systemctl enable drosera.service
  sudo systemctl start drosera.service

  echo "Встановлення завершено! Перейдіть у https://app.drosera.io/ для активації."
}

function view_logs() {
  sudo journalctl -u drosera.service -f
}

function restart_service() {
  echo "Перезапуск drosera.service..."
  sudo systemctl restart drosera.service
  echo "Перезапуск завершено."
}

while true; do
  echo
  echo "==== Меню Drosera ===="
  echo "1) Встановити ноду"
  echo "2) Видалити ноду"
  echo "3) Переглянути логи"
  echo "4) Перезапустити сервіс"
  echo "5) Вийти"
  read -rp "Обери опцію (1-5): " opt

  case $opt in
    1) install_node ;;
    2) remove_node ;;
    3) view_logs ;;
    4) restart_service ;;
    5) echo "Вихід."; exit 0 ;;
    *) echo "Невірний вибір, спробуйте ще раз." ;;
  esac
done
