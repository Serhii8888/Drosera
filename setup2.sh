#!/bin/bash

set -e

echo "====== DRO SERA UPDATE SCRIPT ======"
echo

# ===== 1. Запит RPC =====
read -p "Введіть RPC Hoodi (наприклад http://IP:PORT): " RPC

if [[ -z "$RPC" ]]; then
  echo "❌ RPC не введений. Вихід."
  exit 1
fi

echo "✅ RPC встановлено: $RPC"
sleep 1

# ===== 2. Видалення старої Drosera =====
echo "🧹 Видалення старої інсталяції..."
rm -rf ~/.drosera
rm -rf ~/.drosera/bin

# ===== 3. Встановлення Drosera =====
echo "⬇️ Встановлення нової версії Drosera..."
curl -L https://app.drosera.io/install | bash

echo 'export PATH=$HOME/.drosera/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

droseraup

echo "✅ Версія Drosera:"
/root/.drosera/bin/drosera --version

# ===== 4. Оновлення drosera.toml =====
echo "📂 Перехід у папку проєкту..."
cd ~/my-drosera-trap || { echo "❌ Папка my-drosera-trap не знайдена"; exit 1; }

echo "📝 Оновлення RPC у drosera.toml..."
sed -i "s|^ethereum_rpc = \".*\"|ethereum_rpc = \"$RPC\"|" drosera.toml

echo "✅ RPC у drosera.toml змінено:"
grep ethereum_rpc drosera.toml

# ===== 5. Ввід приватника =====
echo
read -s -p "🔑 Введіть PRIVATE KEY (БЕЗ 0x): " PRIVKEY
echo

if [[ -z "$PRIVKEY" ]]; then
  echo "❌ Приватний ключ не введено"
  exit 1
fi

echo "⚡ Запуск drosera apply..."

# auto підтвердження "ofc"
echo "ofc" | DROSERA_PRIVATE_KEY=$PRIVKEY drosera apply

# ===== 6. Оновлення systemd =====
SERVICE_FILE="/etc/systemd/system/drosera-operator.service"

echo "🛠 Оновлення systemd RPC..."

sudo sed -i "s|Environment=\"DRO__ETH__RPC_URL=.*\"|Environment=\"DRO__ETH__RPC_URL=$RPC\"|" $SERVICE_FILE
sudo sed -i "s|Environment=\"DRO__ETH__BACKUP_RPC_URL=.*\"|Environment=\"DRO__ETH__BACKUP_RPC_URL=$RPC\"|" $SERVICE_FILE

sudo systemctl daemon-reload
sudo systemctl restart drosera-operator.service

# ===== 7. Логи =====
echo
echo "✅ Готово! Показ логів:"
sleep 2
sudo journalctl -u drosera-operator.service -f
