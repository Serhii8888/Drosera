#!/bin/bash
set -e

echo "========== DRO SERA UPDATE =========="
echo ""

# ===== 1. RPC =====
read -p "Введіть RPC Hoodi (http://IP:PORT): " RPC

if [[ -z "$RPC" ]]; then
  echo "❌ RPC не введено!"
  exit 1
fi

# ===== 2. Видалення старої Drosera =====
echo "🧹 Видаляю стару Drosera..."
rm -rf ~/.drosera

# ===== 3. Встановлення Drosera =====
echo "⬇️ Встановлюю Drosera..."
curl -sL https://app.drosera.io/install | bash

# ===== 4. PATH примусово =====
export PATH="$HOME/.drosera/bin:$PATH"

# ===== 5. Запуск droseraup =====
echo "🔧 Запускаю droseraup..."
if [ -f "$HOME/.drosera/bin/droseraup" ]; then
  "$HOME/.drosera/bin/droseraup"
else
  echo "❌ droseraup не знайдено"
  exit 1
fi

# ===== 6. Перевірка drosera =====
if ! command -v drosera >/dev/null 2>&1; then
  echo "❌ drosera не встановилась"
  exit 1
fi

drosera --version

# ===== 7. Оновлення RPC у drosera.toml =====
cd ~/my-drosera-trap || { echo "❌ Немає папки my-drosera-trap"; exit 1; }

sed -i "s|^ethereum_rpc = \".*\"|ethereum_rpc = \"$RPC\"|" drosera.toml

echo "✅ RPC у drosera.toml:"
grep ethereum_rpc drosera.toml

# ===== 8. PRIVATE KEY =====
echo ""
read -s -p "Введіть PRIVATE KEY (без 0x): " PRIVKEY
echo ""

if [[ -z "$PRIVKEY" ]]; then
  echo "❌ Приватник не введено"
  exit 1
fi

# ===== 9. APPLY =====
echo "⚡ Запуск drosera apply..."
echo "ofc" | DROSERA_PRIVATE_KEY="$PRIVKEY" drosera apply

# ===== 10. SYSTEMD =====
SERVICE_FILE="/etc/systemd/system/drosera-operator.service"

echo "🛠 Міняю RPC у systemd..."

sudo sed -i "s|Environment=\"DRO__ETH__RPC_URL=.*\"|Environment=\"DRO__ETH__RPC_URL=$RPC\"|" $SERVICE_FILE
sudo sed -i "s|Environment=\"DRO__ETH__BACKUP_RPC_URL=.*\"|Environment=\"DRO__ETH__BACKUP_RPC_URL=$RPC\"|" $SERVICE_FILE

sudo systemctl daemon-reload
sudo systemctl restart drosera-operator.service

# ===== 11. Логи =====
echo ""
echo "✅ ГОТОВО. Логи ноди:"
sleep 2
sudo journalctl -u drosera-operator.service -f
