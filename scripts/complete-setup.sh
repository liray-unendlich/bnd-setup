#!/bin/bash
# 完全統合セットアップスクリプト
# quick-start.sh実行後、作業用ユーザーで実行する統合スクリプト

set -e

echo "=================================================================="
echo "Boundless ZK Prover 完全統合セットアップ"
echo "=================================================================="
echo "このスクリプトは以下を自動実行します:"
echo "1. 開発環境セットアップ"
echo "2. 設定ファイル編集支援"
echo "3. GitHub認証設定（ブローカー使用時）"
echo "4. ファイアウォール設定"
echo "5. サービス起動"
echo "=================================================================="
echo

# 現在のディレクトリ確認
if [ ! -f "README.md" ] || [ ! -d "scripts" ]; then
    echo "❌ bnd-setupプロジェクトのルートディレクトリで実行してください"
    echo "現在のディレクトリ: $(pwd)"
    echo "実行方法: cd ~/work/bnd-setup && ./scripts/complete-setup.sh"
    exit 1
fi

# ノード種別確認
echo "=== ノード種別選択 ==="
echo "1) ノード1（メインノード: インフラ + API + CPUコンピューティング）"
echo "2) ノード2（GPUノード: GPU証明処理専用）"
echo

read -p "選択してください [1-2]: " -n 1 -r
echo
echo

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

# ================================
# ステップ1: 開発環境セットアップ
# ================================
echo "=== ステップ1: 開発環境セットアップ ==="
./scripts/setup-dev-environment.sh
echo "✓ 開発環境セットアップ完了"
echo

# ================================
# ステップ2: 環境変数設定
# ================================
echo "=== ステップ2: 環境変数設定 ==="

if [ "$NODE_TYPE" = "node1" ]; then
    ENV_FILE="node1-main/.env"
    echo "ノード1の環境変数を設定します: $ENV_FILE"
    echo
    echo "必須設定項目:"
    echo "- POSTGRES_PASSWORD: データベースパスワード（強力なものを設定）"
    echo "- MINIO_ROOT_PASS: MinIOパスワード（強力なものを設定）"
    echo "ブローカー使用時のみ:"
    echo "- PRIVATE_KEY: ブローカー用秘密鍵"
    echo "- RPC_URL: RPC接続URL"
    echo "- WS_RPC_URL: WebSocket RPC URL"
    echo "（※ コントラクトアドレス・ORDER_STREAM_URLはデフォルト値設定済み）"
else
    ENV_FILE="node2-gpu/.env"
    echo "ノード2の環境変数を設定します: $ENV_FILE"
    echo
    echo "重要な設定項目:"
    echo "- NODE1_IP: ノード1のIPアドレス（必須）"
    echo "- パスワード類: ノード1と同じ値に設定"
fi

echo
read -p "環境変数ファイルを編集しますか？ [Y/n]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if command -v vi &> /dev/null; then
        vi "$ENV_FILE"
    elif command -v nano &> /dev/null; then
        nano "$ENV_FILE"
    else
        echo "エディタが見つかりません。手動で編集してください: $ENV_FILE"
    fi
fi

echo "✓ 環境変数設定完了"
echo

# ================================
# ステップ3: ブローカー設定（ノード1のみ）
# ================================
if [ "$NODE_TYPE" = "node1" ]; then
    echo "=== ステップ3: ブローカー設定（オプション） ==="
    echo "ブローカーを使用すると、自動化されたZK証明マーケットプレイス参加が可能です。"
    echo
    read -p "ブローカーを使用しますか？ [y/N]: " -n 1 -r
    echo
    
    # Boundlessプロジェクトの基本セットアップ（ブローカー使用有無に関わらず）
    echo
    echo "--- Boundlessプロジェクトセットアップ ---"
    
    # ~/workディレクトリが存在しない場合は作成
    mkdir -p ~/work
    cd ~/work
    
    # オリジナルBoundlessプロジェクトクローン
    if [ ! -d "boundless" ]; then
        echo "※ オリジナルBoundlessプロジェクトをクローン中..."
        git clone https://github.com/boundless-xyz/boundless.git
        cd boundless
        git checkout v0.13.0
        cd ~/work
    fi
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "ブローカー設定を開始します..."
        
        # GitHub認証設定
        echo
        echo "--- GitHub認証設定 ---"
        cd ~/work/bnd-setup
        ./scripts/setup-github-config.sh
        
        # GitHub認証設定から環境変数を読み込み
        if [ -f ~/.bnd-setup-config ]; then
            source ~/.bnd-setup-config
            
            # ~/workディレクトリに移動
            cd ~/work
            
            # カスタムBoundlessプロジェクトクローン
            if [ ! -d "boundless-custom" ]; then
                echo "※ カスタムBoundlessプロジェクトをクローン中..."
                git clone https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@${BOUNDLESS_REPO_URL} boundless-custom
                cd boundless-custom
                git checkout ${BOUNDLESS_BRANCH}
                cd ~/work
            fi
            
            # カスタムファイルをオリジナルにコピー
            echo "※ カスタムファイルをオリジナルBoundlessにコピー中..."
            
            # コピーするファイルリスト
            COPY_FILES=(
                "Cargo.lock"
                "Cargo.toml"
                "crates/broker/Cargo.toml"
                "crates/broker/src/lib.rs"
                "crates/broker/src/config.rs"
                "crates/broker/src/chain_monitor.rs"
                "crates/broker/src/market_monitor.rs"
                "crates/broker/src/order_monitor.rs"
                "crates/broker/src/order_picker.rs"
                "crates/broker/src/provers/bonsai.rs"
                "crates/broker/src/bin/broker.rs"
                "crates/broker/src/storage.rs"
                "crates/broker/src/prioritization.rs"
                "crates/broker/src/submitter.rs"
                "crates/broker/src/tests/e2e.rs"
                "crates/guest/assessor/assessor-guest/Cargo.lock"
                "crates/boundless-market/src/contracts/mod.rs"
                "crates/boundless-market/src/selector.rs"
            )
            
            # ファイルをコピー
            for file in "${COPY_FILES[@]}"; do
                if [ -f "boundless-custom/$file" ]; then
                    # ディレクトリが存在しない場合は作成
                    mkdir -p "boundless/$(dirname "$file")"
                    cp "boundless-custom/$file" "boundless/$file"
                    echo "  ✓ コピー: $file"
                else
                    echo "  ⚠ ファイルが見つかりません: boundless-custom/$file"
                fi
            done
            
            echo "✓ カスタムファイルのコピー完了"
        else
            echo "⚠ GitHub認証設定が見つかりません。標準Boundlessのみを使用します。"
        fi
        
        # Boundlessプロジェクトのビルド
        echo
        echo "--- Boundlessプロジェクトビルド ---"
        cd ~/work/boundless
        
        echo "※ Solidityコントラクトをビルド中..."
        # 環境変数を読み込み
        source ~/.bashrc
        export PATH="$HOME/.foundry/bin:$PATH"
        if command -v forge &> /dev/null; then
            forge build
            echo "✓ Solidityビルド完了"
        else
            echo "⚠ Forge not found - Solidityビルドをスキップ"
        fi
        
        echo "※ boundless-cliをインストール中..."
        # 環境変数を読み込み
        source ~/.bashrc
        export PATH="$HOME/.cargo/bin:$PATH"
        cargo install --locked boundless-cli
        echo "✓ boundless-cliインストール完了"
        
        echo "※ ブローカーDockerイメージをビルド中..."
        if [ -f "dockerfiles/broker.dockerfile" ]; then
            docker build -f dockerfiles/broker.dockerfile -t boundless-broker .
            echo "✓ ブローカーDockerイメージビルド完了"
        else
            echo "⚠ broker.dockerfile が見つかりません"
        fi
        
        # bnd-setupディレクトリに戻る
        cd ~/work/bnd-setup
        
        echo "✓ ブローカー設定完了"
        BROKER_ENABLED=true
    else
        echo "ブローカー設定をスキップしました"
        
        # ブローカーを使用しない場合でも基本的なBoundlessビルドを実行
        echo
        echo "--- 基本Boundlessプロジェクトビルド ---"
        cd ~/work/boundless
        
        echo "※ Solidityコントラクトをビルド中..."
        # 環境変数を読み込み
        source ~/.bashrc
        export PATH="$HOME/.foundry/bin:$PATH"
        if command -v forge &> /dev/null; then
            forge build
            echo "✓ Solidityビルド完了"
        else
            echo "⚠ Forge not found - Solidityビルドをスキップ"
        fi
        
        echo "※ boundless-cliをインストール中..."
        # 環境変数を読み込み
        source ~/.bashrc
        export PATH="$HOME/.cargo/bin:$PATH"
        cargo install --locked boundless-cli
        echo "✓ boundless-cliインストール完了"
        
        # bnd-setupディレクトリに戻る
        cd ~/work/bnd-setup
        
        BROKER_ENABLED=false
    fi
    echo
fi

# ================================
# ステップ4: ファイアウォール設定
# ================================
echo "=== ステップ4: ファイアウォール設定 ==="

if [ "$NODE_TYPE" = "node1" ]; then
    echo "ノード1のファイアウォールを設定します（パスワード認証ベース）"
    ./scripts/setup-firewall-node1.sh
else
    echo "ノード2のファイアウォールを設定します"
    ./scripts/setup-firewall-node2.sh
fi

echo "✓ ファイアウォール設定完了"
echo

# ================================
# ステップ5: サービス起動
# ================================
echo "=== ステップ5: サービス起動 ==="

if [ "$NODE_TYPE" = "node1" ]; then
    echo "ノード1のサービスを起動します..."
    ./scripts/deploy-node1.sh
else
    echo "ノード2のサービスを起動します..."
    ./scripts/deploy-node2.sh
fi

echo "✓ サービス起動完了"
echo

# ================================
# ステップ6: 動作確認
# ================================
echo "=== ステップ6: 動作確認 ==="

if [ "$NODE_TYPE" = "node1" ]; then
    echo "ノード1の動作確認を実行します..."
    sleep 5
    
    echo "--- サービス状態確認 ---"
    cd node1-main
    docker-compose ps
    cd ..
    echo
    
    echo "--- API動作確認 ---"
    if curl -s http://localhost:8081/health > /dev/null; then
        echo "✓ REST API正常動作中"
    else
        echo "⚠ REST API接続に失敗しました"
    fi
    
    echo
    echo "--- アクセス情報 ---"
    NODE1_IP=$(hostname -I | awk '{print $1}')
    echo "REST API: http://$NODE1_IP:8081"
    echo "Grafana: http://$NODE1_IP:3000 (admin/admin)"
    echo "MinIO Console: http://$NODE1_IP:9001"
    
else
    echo "ノード2の動作確認を実行します..."
    sleep 5
    
    echo "--- GPU証明エージェント確認 ---"
    cd node2-gpu
    docker-compose ps | grep gpu_prove_agent
    cd ..
    echo
    
    echo "--- GPU使用状況確認 ---"
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
    else
        echo "nvidia-smi が見つかりません"
    fi
fi

echo
echo "✓ 動作確認完了"
echo

# ================================
# ブローカー起動（ノード1でブローカー有効時）
# ================================
if [ "$NODE_TYPE" = "node1" ] && [ "$BROKER_ENABLED" = true ]; then
    echo "=== ステップ7: ブローカー起動 ==="
    echo "ブローカーを起動しますか？"
    echo "（事前にBoundlessプロジェクトのビルドが必要です）"
    echo
    read -p "ブローカーを起動しますか？ [y/N]: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "ブローカー起動手順を実行します..."
        echo "詳細な手順については「ブローカー起動（本格運用）」セクションを参照してください"
        echo
        echo "手順概要:"
        echo "1. Boundlessプロジェクトのビルド"
        echo "2. ブローカー設定ファイル編集"
        echo "3. ブローカー起動"
        echo
        echo "次のコマンドで詳細手順を確認できます:"
        echo "less README.md  # 「ブローカー起動（本格運用）」セクション"
    fi
    echo
fi

# ================================
# 完了メッセージ
# ================================
echo "=================================================================="
echo "セットアップ完了！"
echo "=================================================================="
echo "$NODE_NAME ($NODE_TYPE) のセットアップが完了しました。"
echo

if [ "$NODE_TYPE" = "node1" ]; then
    echo "次のステップ:"
    echo "1. ノード2をセットアップする"
    echo "2. ZK証明処理をテストする"
    if [ "$BROKER_ENABLED" = true ]; then
        echo "3. ブローカーを起動する（オプション）"
    fi
else
    echo "次のステップ:"
    echo "1. ノード1からZK証明処理をテストする"
    echo "2. GPU使用状況を監視する"
fi

echo
echo "トラブルシューティング:"
echo "- ログ確認: docker-compose logs -f"
echo "- サービス再起動: docker-compose restart"
echo "- 詳細マニュアル: less README.md"
echo
echo "=================================================================="