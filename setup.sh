#!/bin/bash

function install_node() {
  echo "🧱 Встановлення ноди Drosera..."

  # Встановлення залежностей
  apt update && apt install -y curl unzip git jq

  # Встановлення Drosera CLI
  curl -L https://drosera.network/install.sh | bash

  # Додавання drosera до PATH
  export PATH="$HOME/.drosera/bin:$PATH"
  echo 'export PATH="$HOME/.drosera/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc

  read -rp "Назва вашого Trap (наприклад, mytrap): " TRAP_NAME
  read -rp "Приватний ключ гаманця: " DROSERA_PRIVATE_KEY

  drosera init "$TRAP_NAME"
  cd "$TRAP_NAME" || exit 1

  # Застосування Trap
  echo "🚀 Створення Trap..."
  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF

  echo -e "\n✅ Trap створено! Поповніть його ETH на Holesky."
  read -rp "Натисніть Enter для продовження після поповнення..."

  read -rp "Публічна адреса оператора (0x...): " OPERATOR_ADDRESS

  # Зміна конфігурації
  sed -i 's/private = true/private_trap = true/' drosera.toml
  echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml

  echo "📤 Повторне застосування Trap з whitelist..."
  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF
}

function reapply_trap_config() {
  echo "📥 Повторне застосування конфігурації Trap..."
  read -rp "Приватний ключ гаманця: " DROSERA_PRIVATE_KEY
  read -rp "Публічна адреса оператора (0x...): " OPERATOR_ADDRESS
  read -rp "Назва папки з Trap (наприклад, mytrap): " TRAP_NAME

  cd ~/"$TRAP_NAME" || { echo "❌ Папку $TRAP_NAME не знайдено!"; return 1; }

  if [ ! -f drosera.toml ]; then
    echo "❌ Файл drosera.toml не знайдено!"
    return 1
  fi

  sed -i 's/private = true/private_trap = true/' drosera.toml

  if grep -q "whitelist" drosera.toml; then
    sed -i "s|whitelist = .*|whitelist = [\"$OPERATOR_ADDRESS\"]|" drosera.toml
  else
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
  fi

  echo "📤 Повторне застосування Trap з whitelist..."
  DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY" drosera apply <<EOF
ofc
EOF
}

function remove_node() {
  read -rp "Введіть назву Trap-папки для видалення (наприклад, mytrap): " TRAP_NAME
  rm -rf ~/"$TRAP_NAME"
  echo "🗑️ Ноду Drosera ($TRAP_NAME) видалено."
}

function restart_node() {
  read -rp "Введіть назву Trap-папки (наприклад, mytrap): " TRAP_NAME
  cd ~/"$TRAP_NAME" || { echo "❌ Папку $TRAP_NAME не знайдено!"; return 1; }
  echo "♻️ Перезапуск drosera dryrun..."
  drosera dryrun
}

function main_menu() {
  while true; do
    echo "==============================="
    echo " Drosera Node Installer 🇺🇦"
    echo "==============================="
    echo "1) Встановити ноду"
    echo "2) Видалити ноду"
    echo "3) Перезапустити ноду"
    echo "4) Вийти"
    echo "5) Повторно застосувати Trap (whitelist)"
    read -rp "Ваш вибір (1-5): " choice
    case $choice in
      1) install_node ;;
      2) remove_node ;;
      3) restart_node ;;
      4) echo "👋 До побачення!"; exit 0 ;;
      5) reapply_trap_config ;;
      *) echo "❗ Невірний вибір!" ;;
    esac
  done
}

main_menu
