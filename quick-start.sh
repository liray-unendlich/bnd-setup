#!/bin/bash
# RISC Zero Bento 2ノード分散デプロイ - クイックスタート
# 使用方法: curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/quick-start.sh | bash

set -e

echo "=================================================================="
echo "RISC Zero Bento 2ノード分散デプロイ - クイックスタート"
echo "=================================================================="
echo "GitHubリポジトリをクローンして環境セットアップを開始します"
echo

# 設定
REPO_URL="https://github.com/liray-unendlich/bnd-setup.git"
BRANCH="main"
PROJECT_DIR="bnd-setup"
DEPLOY_DIR=""

# ノード種別選択
echo "デプロイするノードの種別を選択してください:"
echo "1) ノード1 (メインノード: インフラ + API + CPUコンピューティング)"
echo "2) ノード2 (GPUノード: GPU証明処理専用)"
echo

if [ -t 0 ]; then
    # 対話的な場合
    read -p "選択してください [1-2]: " -n 1 -r
    echo
    echo
else
    # パイプ経由の場合、環境変数で選択
    echo "パイプ経由での実行を検出しました。"
    echo "NODE_TYPE環境変数を設定してください: NODE_TYPE=1 または NODE_TYPE=2"
    echo "例: NODE_TYPE=1 curl -fsSL ... | bash"
    
    if [ -z "$NODE_TYPE" ]; then
        echo "エラー: NODE_TYPE環境変数が設定されていません"
        echo "以下のいずれかの方法で実行してください："
        echo ""
        echo "方法1: 環境変数を設定してから実行"
        echo "  export NODE_TYPE=1"
        echo "  curl -fsSL https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh | bash"
        echo ""
        echo "方法2: wgetでダウンロードして実行"
        echo "  wget https://raw.githubusercontent.com/liray-unendlich/bnd-setup/main/quick-start.sh"
        echo "  chmod +x quick-start.sh"
        echo "  ./quick-start.sh"
        exit 1
    fi
    REPLY=$NODE_TYPE
fi

case $REPLY in
    1)
        NODE_TYPE="node1"
        NODE_NAME="メインノード"
        ;;
    2)
        NODE_TYPE="node2"
        NODE_NAME="GPUノード"
        ;;
    *)
        echo "無効な選択です。1または2を選択してください。"
        exit 1
        ;;
esac

echo "選択: $NODE_NAME ($NODE_TYPE)"
echo

# 既存ディレクトリチェック
if [ -d "$PROJECT_DIR" ]; then
    echo "既存のプロジェクトディレクトリが見つかりました: $PROJECT_DIR"
    if [ -t 0 ]; then
        read -p "削除して新しくクローンしますか？ [y/N]: " -n 1 -r
        echo
    else
        echo "既存ディレクトリを削除して新しくクローンします..."
        REPLY="y"
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
        echo "既存ディレクトリを削除しました"
    else
        echo "既存ディレクトリを使用します"
        cd "$PROJECT_DIR"
        git pull origin $BRANCH 2>/dev/null || echo "Git pull failed - continuing"
    fi
else
    # プロジェクトクローン
    echo "GitHubリポジトリをクローン中..."
    git clone -b $BRANCH $REPO_URL $PROJECT_DIR
    cd "$PROJECT_DIR"
fi

# デプロイディレクトリに移動（既にルートディレクトリにいる場合はそのまま）
if [ -n "$DEPLOY_DIR" ] && [ ! -d "$DEPLOY_DIR" ]; then
    echo "エラー: デプロイディレクトリが見つかりません: $DEPLOY_DIR"
    exit 1
fi

if [ -n "$DEPLOY_DIR" ]; then
    cd "$DEPLOY_DIR"
fi
echo "作業ディレクトリ: $(pwd)"
echo

# rootユーザーチェック
if [ "$EUID" -eq 0 ]; then
    echo "rootユーザーでの実行が検出されました"
    
    # rootセットアップ実行
    if [ "$NODE_TYPE" = "node1" ]; then
        echo "ノード1のrootセットアップを実行します..."
        ./scripts/setup-node1-root.sh
    else
        echo "ノード2のrootセットアップを実行します..."
        ./scripts/setup-node2-root.sh
    fi
    
    echo
    echo "=================================================================="
    echo "rootセットアップ完了！"
    echo "=================================================================="
    echo "システムを再起動してから、作業用ユーザーでログインして"
    echo "以下のコマンドを実行してください："
    echo
    echo "cd $(pwd)"
    echo "./scripts/setup-dev-environment.sh"
    echo
    echo "システム再起動中..."
    sleep 3
    reboot
    
else
    echo "一般ユーザーでの実行が検出されました"
    
    # 開発環境セットアップ
    echo "開発環境セットアップを実行します..."
    ./scripts/setup-dev-environment.sh
    
    echo
    echo "次のステップ:"
    echo "1. 環境変数ファイルを編集してください:"
    
    if [ "$NODE_TYPE" = "node1" ]; then
        echo "   vi node1-main/.env"
        echo
        echo "2. ファイアウォール設定を実行してください:"
        echo "   ./scripts/setup-firewall-node1.sh <ノード2のIP>"
        echo
        echo "3. デプロイを実行してください:"
        echo "   ./scripts/deploy-node1.sh"
    else
        echo "   vi node2-gpu/.env  # NODE1_IPを実際の値に設定"
        echo
        echo "2. ファイアウォール設定を実行してください:"
        echo "   ./scripts/setup-firewall-node2.sh"
        echo
        echo "3. デプロイを実行してください:"
        echo "   ./scripts/deploy-node2.sh"
    fi
    
    echo
    echo "詳細な手順については README.md を参照してください"
fi

echo
echo "=================================================================="
echo "セットアップ完了！"
echo "=================================================================="