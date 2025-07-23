#!/bin/bash
# ノード1用ファイアウォール設定スクリプト

set -e

echo "=== ノード1 ファイアウォール設定スクリプト ==="
echo "このスクリプトはノード1（メインノード）のファイアウォールを設定します"
echo

# ノード2のIPアドレス取得
if [ -z "$1" ]; then
    echo "使用方法: $0 <NODE2_IP>"
    echo "例: $0 192.168.1.101"
    echo
    echo "NODE2_IP: ノード2（GPUノード）のIPアドレス"
    exit 1
fi

NODE2_IP="$1"

# IPアドレス形式チェック
if ! [[ $NODE2_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "エラー: 無効なIPアドレス形式です: $NODE2_IP"
    exit 1
fi

echo "ノード2 IPアドレス: $NODE2_IP"
echo

# UFWがインストールされているか確認
if ! command -v ufw &> /dev/null; then
    echo "UFWがインストールされていません。インストール中..."
    sudo apt-get update
    sudo apt-get install -y ufw
fi

# 現在の設定表示
echo "現在のファイアウォール設定:"
sudo ufw status
echo

echo "新しいファイアウォール設定を適用しています..."

# ファイアウォールリセット（慎重に）
echo "ファイアウォール設定をリセットします..."
sudo ufw --force reset

# デフォルトポリシー設定
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH接続許可（重要：リモート接続が切れないように）
sudo ufw allow ssh
echo "✓ SSH (22) 許可"

# 外部アクセス用ポート開放（Grafanaのみ）
sudo ufw allow 3000/tcp comment "Grafana Dashboard"
echo "✓ Grafana (3000) 許可"

# ノード2からのアクセス許可
sudo ufw allow from $NODE2_IP to any port 5432 comment "PostgreSQL from Node2"
echo "✓ PostgreSQL (5432) from $NODE2_IP 許可"

sudo ufw allow from $NODE2_IP to any port 6379 comment "Redis from Node2"
echo "✓ Redis (6379) from $NODE2_IP 許可"

sudo ufw allow from $NODE2_IP to any port 9000 comment "MinIO from Node2"
echo "✓ MinIO (9000) from $NODE2_IP 許可"

sudo ufw allow from $NODE2_IP to any port 8081 comment "REST API from Node2"
echo "✓ REST API (8081) from $NODE2_IP 許可"

sudo ufw allow from $NODE2_IP to any port 9001 comment "MinIO Console from Node2"
echo "✓ MinIO Console (9001) from $NODE2_IP 許可"

# ファイアウォール有効化
echo
echo "ファイアウォールを有効化しています..."
sudo ufw --force enable

echo
echo "=== 設定完了 ==="
echo "新しいファイアウォール設定:"
sudo ufw status numbered
echo

echo "=== 設定内容 ==="
echo "許可されたポート:"
echo "  - SSH (22): 全てから"
echo "  - Grafana (3000): 全てから"
echo "  - PostgreSQL (5432): $NODE2_IP から"
echo "  - Redis (6379): $NODE2_IP から"
echo "  - MinIO (9000): $NODE2_IP から"
echo "  - REST API (8081): $NODE2_IP から"
echo "  - MinIO Console (9001): $NODE2_IP から"
echo

echo "=== 注意事項 ==="
echo "1. SSH接続は維持されますが、新しい接続でテストしてください"
echo "2. ノード2のIPアドレスが変更された場合は、再度このスクリプトを実行してください"
echo "3. 設定を無効化したい場合: sudo ufw disable"
echo "4. 設定を確認したい場合: sudo ufw status verbose"