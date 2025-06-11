#!/bin/bash
set -e

SERVICE="drosera.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE"

function prompt_nonempty() {
  local prompt_msg=$1
  local input_var
  while true; do
    read -rp "$prompt_msg: " input_var
    if [[ -n "$input_var" ]]; then
      echo "$input_var"
      break
    else
      echo "Значення не може бути порожнім, спробуйте ще раз."
    fi
  done
}

function remove_node() {
  echo "=== Починаємо видалення існуючої ноди Drosera ==="

  if systemctl is-active --quiet $SERVICE; then
    echo "Зупинка сервісу $SERVICE..."
    sudo systemctl stop $SERVICE
  fi

  if systemctl is-enabled --quiet $SERVICE; then
    echo "Вимикаємо автозапуск $SERVICE..."
    sudo systemctl disable $SERVICE
  fi

  if systemctl list-units --all | grep -q "$SERVICE"; then
    echo "Видаляємо systemd-сервіс $SERVICE..."
    sudo rm -f $SERVICE_PATH
    sudo systemctl daemon-reload
  fi

  echo "Видаляємо drosera CLI та пов'язані файли..."
  rm -rf ~/.drosera ~/.foundry ~/.bun ~/my-drosera-trap
  rm -f ~/.bashrc_drosera_path ~/.bashrc_bun_path ~/.bashrc_foundry_path ~/.foundryup ~/.bun

  echo "Видалення завершено."
}

function install_node() {
  echo "=== Починаємо установку Drosera ==="

  # Запитуємо дані у користувача
  local git_email=$(prompt_nonempty "Введіть email для git (наприклад, you@example.com)")
  local git_user=$(prompt_nonempty "Введіть ім'я користувача для git (github-username)")
  local drosera_address=$(prompt_nonempty "Введіть вашу Drosera адресу (наприклад, 0xYourDroseraAddress)")
  local rpc_url=$(prompt_nonempty "Введіть RPC URL (наприклад, https://rpc.holesky.testnet)")

  # Оновлення системи (опційно)
  sudo apt update && sudo apt upgrade -y

  # Встановлення залежностей
  sudo apt install -y curl git build-essential pkg-config libssl-dev jq ufw

  # Встановлення Docker (офіційний скрипт з видаленням конфліктів)
  if ! command -v docker &>/dev/null; then
    echo "Встановлення Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc containerd.io || true
    curl -fsSL https://get.docker.com | sudo bash
    sudo systemctl enable docker
    sudo systemctl start docker
  else
    echo "Docker вже встановлений."
  fi

  # Встановлення Drosera CLI
  echo "Встановлення Drosera CLI..."
  curl -L https://app.drosera.io/install | bash

  # Завантаження PATH для drosera CLI
  source ~/.bashrc || true

  # Оновлення drosera CLI, якщо можливо
  if command -v droseraup &>/dev/null; then
    droseraup || echo "droseraup не спрацював, але продовжуємо"
  fi

  # Встановлення Foundry
  echo "Встановлення Foundry (forge)..."
  curl -L https://foundry.paradigm.xyz | bash
  source ~/.bashrc || true
  foundryup || true
  source ~/.bashrc || true

  # Встановлення Bun
  echo "Встановлення Bun..."
  curl -fsSL https://bun.sh/install | bash
  source ~/.bashrc || true
  export PATH="$HOME/.bun/bin:$PATH"

  # Перевірка встановлення CLI
  for cmd in drosera forge bun; do
    if ! command -v $cmd &>/dev/null; then
      echo "Помилка: $cmd не знайдено у PATH. Переконайтеся, що .bashrc завантажено."
      exit 1
    fi
  done

  echo "Ініціалізація drosera trap..."
  mkdir -p ~/my-drosera-trap
  cd ~/my-drosera-trap

  # Налаштування git з введеними даними
  git config --global user.email "$git_email"
  git config --global user.name "$git_user"

  forge init -t drosera-network/trap-foundry-template || true

  bun install || true
  forge build || true

  echo "Реєстрація оператора..."
  drosera-operator register --drosera-address "$drosera_address" --rpc-url "$rpc_url" || \
    echo "Реєстрація не пройшла, перевірте адреси та RPC."

  # Налаштування firewall (опційно)
  echo "Налаштування Firewall..."
  sudo ufw allow 22/tcp
  sudo ufw allow 26656/tcp
  sudo ufw --force enable

  # Створення systemd сервісу
  echo "Створення systemd сервісу drosera.service..."
  sudo tee $SERVICE_PATH > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network.target docker.service
Requires=docker.service

[Service]
User=$USER
ExecStart=$(command -v drosera) run
Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE
  sudo systemctl start $SERVICE

  echo "Установка завершена! Перевіряйте логи командою:"
  echo "journalctl -u $SERVICE -f"
  echo "Для активації оператора перейдіть на https://app.drosera.io/"
}

function view_logs() {
  sudo journalctl -u $SERVICE -f
}

function restart_service() {
  echo "Перезапуск $SERVICE..."
  sudo systemctl restart $SERVICE
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
