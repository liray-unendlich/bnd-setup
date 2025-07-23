#!/bin/bash
# ノード2用ファイアウォール設定スクリプト

set -e

echo "=== ノード2 ファイアウォール設定スクリプト ==="
echo "このスクリプトはノード2（GPUノード）のファイアウォールを設定します"
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

# GPU監視ポート（オプション）
read -p "GPU監視ポート（例：nvidia-ml-py用 3333）を開放しますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "ポート番号を入力してください [3333]: " GPU_PORT
    GPU_PORT=${GPU_PORT:-3333}
    sudo ufw allow $GPU_PORT/tcp comment "GPU Monitoring"
    echo "✓ GPU監視ポート ($GPU_PORT) 許可"
fi

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
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  - GPU監視 ($GPU_PORT): 全てから"
fi
echo

echo "=== 特記事項 ==="
echo "- ノード2は外部からの接続を受け付けません（SSH除く）"
echo "- ノード1への送信接続のみ行います"
echo "- GPU処理専用ノードとして動作します"
echo

echo "=== 注意事項 ==="
echo "1. SSH接続は維持されますが、新しい接続でテストしてください"
echo "2. 設定を無効化したい場合: sudo ufw disable"
echo "3. 設定を確認したい場合: sudo ufw status verbose"