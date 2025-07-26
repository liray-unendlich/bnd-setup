#!/bin/bash
# ノード1用ファイアウォール設定スクリプト

set -e

echo "=== ノード1 ファイアウォール設定スクリプト ==="
echo "このスクリプトはノード1（メインノード）のファイアウォールを設定します"
echo

# パスワード認証を使用するため、IP制限は不要
echo "パスワード認証ベースの設定を適用します"
echo "PostgreSQL、Redis、MinIOはパスワードで保護されています"
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

# ノード2からのアクセス許可（パスワード認証ベース）
sudo ufw allow 5432/tcp comment "PostgreSQL (password auth)"
echo "✓ PostgreSQL (5432) 許可（パスワード認証）"

sudo ufw allow 6379/tcp comment "Redis (password auth)"
echo "✓ Redis (6379) 許可（パスワード認証）"

sudo ufw allow 9000/tcp comment "MinIO (password auth)"
echo "✓ MinIO (9000) 許可（パスワード認証）"

sudo ufw allow 8081/tcp comment "REST API (no auth required)"
echo "✓ REST API (8081) 許可"

sudo ufw allow 9001/tcp comment "MinIO Console (password auth)"
echo "✓ MinIO Console (9001) 許可（パスワード認証）"

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
echo "  - PostgreSQL (5432): 全てから（パスワード認証）"
echo "  - Redis (6379): 全てから（パスワード認証）"
echo "  - MinIO (9000): 全てから（パスワード認証）"
echo "  - REST API (8081): 全てから"
echo "  - MinIO Console (9001): 全てから（パスワード認証）"
echo

echo "=== 注意事項 ==="
echo "1. SSH接続は維持されますが、新しい接続でテストしてください"
echo "2. パスワード認証ベースのため、IPアドレス制限はありません"
echo "3. PostgreSQL、Redis、MinIOはパスワードで保護されています"
echo "4. 設定を無効化したい場合: sudo ufw disable"
echo "5. 設定を確認したい場合: sudo ufw status verbose"