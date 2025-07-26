#!/bin/bash
# GitHub設定スクリプト
# Boundlessカスタムリポジトリアクセス用の認証情報を設定します

set -e

echo "=== GitHub設定スクリプト ==="
echo "カスタムBoundlessリポジトリアクセス用の設定を行います"
echo

CONFIG_FILE="$HOME/.bnd-setup-config"

# 既存設定の確認
if [ -f "$CONFIG_FILE" ]; then
    echo "既存の設定ファイルが見つかりました: $CONFIG_FILE"
    source "$CONFIG_FILE"
    
    echo "現在の設定:"
    echo "  GitHubユーザー名: ${GITHUB_USERNAME:-未設定}"
    echo "  Personal Access Token: ${GITHUB_TOKEN:+設定済み}" 
    echo "  リポジトリURL: ${BOUNDLESS_REPO_URL:-未設定}"
    echo "  ブランチ: ${BOUNDLESS_BRANCH:-未設定}"
    echo
    
    read -p "設定を更新しますか？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "設定をそのまま使用します"
        exit 0
    fi
fi

echo "=== GitHub認証情報設定 ==="

# GitHubユーザー名
while [ -z "$GITHUB_USERNAME_NEW" ]; do
    read -p "GitHubユーザー名: " GITHUB_USERNAME_NEW
    if [ -z "$GITHUB_USERNAME_NEW" ]; then
        echo "ユーザー名は必須です"
    fi
done

# GitHub Personal Access Token
while [ -z "$GITHUB_TOKEN_NEW" ]; do
    read -sp "GitHub Personal Access Token: " GITHUB_TOKEN_NEW
    echo
    if [ -z "$GITHUB_TOKEN_NEW" ]; then
        echo "Personal Access Tokenは必須です"
        echo "GitHub → Settings → Developer settings → Personal access tokens で作成してください"
        echo "必要な権限: repo (プライベートリポジトリの場合)"
    fi
done

# リポジトリURL
echo
echo "=== Boundlessリポジトリ設定 ==="
read -p "Boundlessリポジトリ（デフォルト: github.com/0xmakase/boundless-custom.git）: " REPO_INPUT
BOUNDLESS_REPO_URL_NEW=${REPO_INPUT:-"github.com/0xmakase/boundless-custom.git"}

# ブランチ名
read -p "ブランチ名（デフォルト: chore/new-order-lock-feature）: " BRANCH_INPUT
BOUNDLESS_BRANCH_NEW=${BRANCH_INPUT:-"chore/new-order-lock-feature"}

echo
echo "=== 設定確認 ==="
echo "GitHubユーザー名: $GITHUB_USERNAME_NEW"
echo "Personal Access Token: ${GITHUB_TOKEN_NEW:0:8}..."
echo "リポジトリURL: $BOUNDLESS_REPO_URL_NEW"
echo "ブランチ: $BOUNDLESS_BRANCH_NEW"
echo

read -p "この設定で保存しますか？ [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "設定をキャンセルしました"
    exit 1
fi

# 設定保存
cat > "$CONFIG_FILE" << EOF
# bnd-setup GitHub設定
# このファイルには認証情報が含まれるため、他者と共有しないでください
GITHUB_USERNAME="$GITHUB_USERNAME_NEW"
GITHUB_TOKEN="$GITHUB_TOKEN_NEW"
BOUNDLESS_REPO_URL="$BOUNDLESS_REPO_URL_NEW"
BOUNDLESS_BRANCH="$BOUNDLESS_BRANCH_NEW"
EOF

# ファイル権限設定（所有者のみ読み書き可能）
chmod 600 "$CONFIG_FILE"

echo "✓ 設定を $CONFIG_FILE に保存しました"
echo

# 接続テスト
echo "=== 接続テスト ==="
echo "GitHub認証をテストしています..."

if curl -s -H "Authorization: token $GITHUB_TOKEN_NEW" \
   "https://api.github.com/repos/${BOUNDLESS_REPO_URL_NEW%%.git*}" \
   | grep -q '"name"'; then
    echo "✓ GitHub認証成功"
    echo "✓ リポジトリアクセス確認済み"
else
    echo "⚠ GitHub認証またはリポジトリアクセスに問題があります"
    echo "以下を確認してください:"
    echo "  - Personal Access Tokenが正しいか"
    echo "  - リポジトリURLが正しいか"
    echo "  - リポジトリへのアクセス権限があるか"
fi

echo
echo "=== 使用方法 ==="
echo "設定完了後、以下のコマンドでBoundlessプロジェクトをクローンできます:"
echo
echo "  cd ~/work"
echo "  source ~/.bnd-setup-config"
echo "  git clone https://\${GITHUB_USERNAME}:\${GITHUB_TOKEN}@\${BOUNDLESS_REPO_URL}"
echo
echo "または、ブローカー起動時に自動的に使用されます。"
echo

echo "=== セキュリティ注意事項 ==="
echo "- ~/.bnd-setup-config ファイルには認証情報が含まれます"
echo "- このファイルを他者と共有しないでください"
echo "- 不要になったらファイルを削除してください: rm ~/.bnd-setup-config"
echo "- Personal Access Tokenは定期的にローテーションすることを推奨します"