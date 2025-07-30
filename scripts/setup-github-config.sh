#!/bin/bash
# GitHub認証設定スクリプト

set -e

echo "=== GitHub認証設定 ==="
echo "カスタムBoundlessプロジェクト用のGitHub認証情報を設定します"
echo

CONFIG_FILE="$HOME/.bnd-setup-config"

# 既存設定を読み込み
if [ -f "$CONFIG_FILE" ]; then
    echo "既存の設定ファイルが見つかりました: $CONFIG_FILE"
    source "$CONFIG_FILE"
    echo
    echo "現在の設定:"
    echo "  GitHub Username: ${GITHUB_USERNAME:-未設定}"
    echo "  GitHub Token: ${GITHUB_TOKEN:+設定済み}" 
    echo "  Repository URL: ${BOUNDLESS_REPO_URL:-未設定}"
    echo "  Branch: ${BOUNDLESS_BRANCH:-未設定}"
    echo
    
    read -p "既存設定を使用しますか？ [Y/n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "✓ 既存設定を使用します"
        exit 0
    fi
fi

echo "新しい認証情報を設定します..."
echo

# GitHub Username
read -p "GitHub Username: " GITHUB_USERNAME_NEW
if [ -z "$GITHUB_USERNAME_NEW" ]; then
    echo "❌ GitHub Usernameは必須です"
    exit 1
fi

# GitHub Personal Access Token
echo
echo "GitHub Personal Access Token (PAT) を入力してください:"
echo "※ repo権限が必要です"
read -s -p "GitHub Token: " GITHUB_TOKEN_NEW
echo
if [ -z "$GITHUB_TOKEN_NEW" ]; then
    echo "❌ GitHub Tokenは必須です"
    exit 1
fi

# Repository URL
echo
read -p "Boundless Repository URL (例: github.com/user/boundless-custom.git): " BOUNDLESS_REPO_URL_NEW
if [ -z "$BOUNDLESS_REPO_URL_NEW" ]; then
    echo "❌ Repository URLは必須です"
    exit 1
fi

# Branch
echo
read -p "Branch (例: chore/new-order-lock-feature): " BOUNDLESS_BRANCH_NEW
if [ -z "$BOUNDLESS_BRANCH_NEW" ]; then
    BOUNDLESS_BRANCH_NEW="main"
    echo "デフォルトブランチ 'main' を使用します"
fi

# 設定ファイルに保存
echo
echo "設定を保存中..."
cat > "$CONFIG_FILE" << EOF
# BND Setup GitHub Configuration
GITHUB_USERNAME="$GITHUB_USERNAME_NEW"
GITHUB_TOKEN="$GITHUB_TOKEN_NEW"
BOUNDLESS_REPO_URL="$BOUNDLESS_REPO_URL_NEW"
BOUNDLESS_BRANCH="$BOUNDLESS_BRANCH_NEW"
EOF

# ファイル権限を制限
chmod 600 "$CONFIG_FILE"

echo "✓ GitHub認証設定完了"
echo "設定ファイル: $CONFIG_FILE"
echo
echo "設定内容:"
echo "  GitHub Username: $GITHUB_USERNAME_NEW"
echo "  GitHub Token: ********"
echo "  Repository URL: $BOUNDLESS_REPO_URL_NEW"  
echo "  Branch: $BOUNDLESS_BRANCH_NEW"