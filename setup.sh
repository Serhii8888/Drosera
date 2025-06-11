#!/bin/bash
set -e

NODE_USER="$USER"
SERVICE_NAME="drosera.service"

function check_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Команда $1 не встановлена або не в PATH. Встанови її перш ніж продовжувати."
    exit 1
  }
}

function uninstall_node() {
  echo "=== Видалення Drosera ==="
  if systemctl is-active --quiet $SERVICE_NAME; then
    echo "Зупинка сервісу..."
    sudo systemctl stop $SERVICE_NAME
  fi
  if systemctl is-enabled --quiet $SERVICE_NAME; then
    echo "Вимикання автозапуску..."
    sudo systemctl disable $SERVICE_NAME
  fi
  if systemctl list-units --all | grep -q $SERVICE_NAME; then
    echo "Видалення systemd-сервісу..."
    sudo rm -f /etc/systemd/system/$SERVICE_NAME
    sudo systemctl daemon-reload
  fi

  echo "Видалення CLI, конфігів і файлів..."
  rm -rf ~/.drosera ~/.foundry ~/.bun ~/my-drosera-trap
  echo "Видалення завершено."
}

function install_node() {
  echo "=== Встановлення Drosera ==="

  # Встановлення залежностей
  sudo apt update && sudo apt install -y curl git build-essential pkg-config libssl-dev jq ufw docker.io

  # Переконуємось, що Docker запущено
  sudo systemctl enable --now docker

  # Встановлення Drosera CLI
  curl -L https://app.drosera.io/install | bash
  source ~/.bashrc || true

  # Встановлення Foundry
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc || true
  foundryup || true
  source ~/.bashrc || true

  # Встановлення Bun
  curl -fsSL https://bun.sh/install | bash
  source ~/.bashrc || true
  export PATH="$HOME/.bun/bin:$PATH"

  # Перевірка наявності команд
  for cmd in drosera forge bun; do
    check_command "$cmd"
  done

  # Ініціалізація drosera trap
  mkdir -p ~/my-drosera-trap
  cd ~/my-drosera-trap

  # Ініціалізація проекту forge
  forge init -t drosera-network/trap-foundry-template

  bun install
  forge build

  # Тут можна вставити інструкцію для реєстрації оператора або залишити користувачу робити вручну
  echo "Не забудь зареєструвати оператора вручну, замінивши адреси."

  # Налаштування firewall
  sudo ufw allow 22/tcp
  sudo ufw allow 26656/tcp
  sudo ufw --force enable

  # Створення systemd сервісу
  sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network.target docker.service
Requires=docker.service

[Service]
User=$NODE_USER
ExecStart=/usr/bin/drosera run
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME
  sudo systemctl start $SERVICE_NAME

  echo "Встановлення завершено!"
}

function show_logs() {
  echo "=== Логи сервісу Drosera ==="
  sudo journalctl -u $SERVICE_NAME -f
}

function restart_service() {
  echo "=== Перезапуск сервісу Drosera ==="
  sudo systemctl restart $SERVICE_NAME
  echo "Сервіс перезапущено."
}

while true; do
  echo ""
  echo "==== Меню Drosera ===="
  echo "1) Встановити ноду"
  echo "2) Видалити ноду"
  echo "3) Переглянути логи"
  echo "4) Перезапустити сервіс"
  echo "5) Вийти"
  echo -n "Обери опцію (1-5): "
  read -r choice
  case $choice in
    1) install_node ;;
    2) uninstall_node ;;
    3) show_logs ;;
    4) restart_service ;;
    5) echo "Вихід..."; exit 0 ;;
    *) echo "Невірний вибір, спробуй ще." ;;
  esac
done
