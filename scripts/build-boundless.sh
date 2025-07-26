#!/bin/bash
# Boundlessプロジェクト自動ビルドスクリプト

set -e

echo "=================================================================="
echo "Boundless プロジェクト自動ビルドスクリプト"
echo "=================================================================="
echo "このスクリプトは以下を実行します:"
echo "1. 環境確認"
echo "2. Solidityコントラクトビルド (forge build)"
echo "3. Rustクレートビルド (cargo build)"
echo "4. ドキュメント生成（オプション）"
echo "=================================================================="
echo

# プロジェクトディレクトリ確認
PROJECT_DIR="${1:-$PWD}"
if [ ! -f "$PROJECT_DIR/Cargo.toml" ] && [ ! -f "$PROJECT_DIR/foundry.toml" ]; then
    echo "エラー: Boundlessプロジェクトディレクトリが見つかりません"
    echo "使用方法: $0 [プロジェクトディレクトリ]"
    echo "現在のディレクトリ: $PWD"
    exit 1
fi

cd "$PROJECT_DIR"
echo "プロジェクトディレクトリ: $PWD"
echo

# ================================
# 環境確認
# ================================
echo "=== 開発環境確認 ==="

# 必要なツールの確認
REQUIRED_TOOLS=("rustc" "cargo" "forge" "cast")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool: $(${tool} --version | head -n1)"
    else
        echo "✗ $tool: 未インストール"
        MISSING_TOOLS+=("$tool")
    fi
done

# RISC Zero確認（特別扱い）
if cargo risczero --version &> /dev/null; then
    echo "✓ cargo-risczero: $(cargo risczero --version | head -n1)"
else
    echo "✗ cargo-risczero: 未インストール"
    MISSING_TOOLS+=("cargo-risczero")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo
    echo "エラー: 以下のツールが不足しています:"
    printf ' - %s\n' "${MISSING_TOOLS[@]}"
    echo "setup-dev-environment.sh を先に実行してください"
    exit 1
fi

echo "✓ 環境確認完了"
echo

# ================================
# ビルド設定確認
# ================================
echo "=== ビルド設定確認 ==="

# ビルドモード選択
BUILD_MODE="debug"
read -p "リリースビルドを実行しますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    BUILD_MODE="release"
    CARGO_FLAGS="--release"
    echo "リリースビルドモードを選択"
else
    CARGO_FLAGS=""
    echo "デバッグビルドモードを選択"
fi

# 並列ビルド設定
CPU_CORES=$(nproc 2>/dev/null || echo "4")
PARALLEL_JOBS=$((CPU_CORES > 8 ? 8 : CPU_CORES))
echo "並列ビルドジョブ数: $PARALLEL_JOBS"

# 環境変数設定
export RISC0_DEV_MODE=1
export CARGO_BUILD_JOBS=$PARALLEL_JOBS
echo "✓ ビルド設定完了"
echo

# ================================
# 依存関係インストール・更新
# ================================
echo "=== 依存関係更新 ==="

# Gitサブモジュール更新
if [ -f ".gitmodules" ]; then
    echo "Gitサブモジュール更新中..."
    git submodule update --init --recursive
    echo "✓ Gitサブモジュール更新完了"
fi

# Foundry依存関係インストール
if [ -f "foundry.toml" ]; then
    echo "Foundry依存関係インストール中..."
    forge install --root . 2>/dev/null || echo "Foundry依存関係は既に最新です"
    echo "✓ Foundry依存関係確認完了"
fi

# Rust依存関係更新（オプション）
read -p "Rust依存関係を更新しますか？（時間がかかる場合があります） [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rust依存関係更新中..."
    cargo update
    echo "✓ Rust依存関係更新完了"
fi

echo

# ================================
# Solidityコントラクトビルド
# ================================
echo "=== Solidityコントラクトビルド ==="

if [ -f "foundry.toml" ] || [ -d "contracts" ] || [ -d "src" ]; then
    echo "Solidityコントラクトをビルド中..."
    
    # forge clean（オプション）
    read -p "クリーンビルドを実行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        forge clean
        echo "✓ クリーンアップ完了"
    fi
    
    # ビルド実行
    if forge build; then
        echo "✓ Solidityコントラクトビルド完了"
    else
        echo "✗ Solidityコントラクトビルドに失敗しました"
        exit 1
    fi
    
    # コントラクトサイズ確認
    if command -v forge-fmt &> /dev/null; then
        echo "コントラクトサイズ確認中..."
        forge build --sizes 2>/dev/null || echo "サイズ情報の取得に失敗"
    fi
else
    echo "Solidityコントラクトが見つかりません - スキップ"
fi
echo

# ================================
# Rustクレートビルド
# ================================
echo "=== Rustクレートビルド ==="

if [ -f "Cargo.toml" ]; then
    echo "Rustクレートをビルド中..."
    
    # cargo clean（オプション）
    if [[ $REPLY =~ ^[Yy]$ ]]; then  # 前のクリーンビルド選択を再利用
        echo "Rustクレートクリーンアップ中..."
        cargo clean
        echo "✓ クリーンアップ完了"
    fi
    
    # ビルド実行
    echo "cargo build $CARGO_FLAGS --jobs $PARALLEL_JOBS を実行中..."
    if cargo build $CARGO_FLAGS --jobs $PARALLEL_JOBS; then
        echo "✓ Rustクレートビルド完了"
    else
        echo "✗ Rustクレートビルドに失敗しました"
        exit 1
    fi
    
    # brokerのDockerイメージビルド
    echo "brokerのDockerイメージをビルド中..."
    if [ -f "dockerfiles/broker.dockerfile" ]; then
        if docker build -f dockerfiles/broker.dockerfile -t boundless-broker .; then
            echo "✓ Broker Dockerイメージビルド完了"
            docker images | grep boundless-broker
        else
            echo "❌ Broker Dockerイメージビルドに失敗しました"
            exit 1
        fi
    else
        echo "⚠ dockerfiles/broker.dockerfile が見つかりません - スキップ"
    fi
    
    # テスト実行（オプション）
    read -p "テストを実行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "テスト実行中..."
        if cargo test $CARGO_FLAGS; then
            echo "✓ テスト成功"
        else
            echo "⚠ テストに失敗しました"
        fi
    fi
else
    echo "Cargo.tomlが見つかりません - スキップ"
fi
echo

# ================================
# RISC Zero証明生成テスト（オプション）
# ================================
echo "=== RISC Zero証明生成テスト ==="

read -p "RISC Zero証明生成テストを実行しますか？（時間がかかります） [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "Cargo.toml" ] && grep -q "risc0" Cargo.toml; then
        echo "RISC Zero証明生成テスト実行中..."
        # 開発モードで高速テスト
        RISC0_DEV_MODE=1 cargo test --release --bin guest-* 2>/dev/null || {
            echo "専用のテストが見つかりません - 通常のテストで代用"
            RISC0_DEV_MODE=1 cargo test --release
        }
        echo "✓ RISC Zero証明生成テスト完了"
    else
        echo "RISC Zeroの設定が見つかりません - スキップ"
    fi
fi
echo

# ================================
# ドキュメント生成（オプション）
# ================================
echo "=== ドキュメント生成 ==="

read -p "ドキュメントを生成しますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Rustドキュメント
    if [ -f "Cargo.toml" ]; then
        echo "Rustドキュメント生成中..."
        cargo doc --no-deps $CARGO_FLAGS
        echo "✓ Rustドキュメント生成完了"
        echo "ドキュメント: ./target/doc/index.html"
    fi
    
    # Webドキュメント（bun/npm）
    if [ -f "package.json" ] && command -v bun &> /dev/null; then
        echo "Webドキュメント生成中..."
        if [ ! -d "node_modules" ]; then
            bun install
        fi
        
        echo "ドキュメントサーバーをバックグラウンドで起動中..."
        bun run docs &
        DOC_PID=$!
        
        echo "ドキュメントサーバーPID: $DOC_PID"
        echo "アクセス: http://localhost:5173"
        echo "停止: kill $DOC_PID"
    fi
fi
echo

# ================================
# ビルド成果物確認
# ================================
echo "=== ビルド成果物確認 ==="

echo "ビルド成果物:"

# Solidityアーティファクト
if [ -d "out" ] || [ -d "artifacts" ]; then
    SOLIDITY_ARTIFACTS=$(find out artifacts -name "*.json" 2>/dev/null | wc -l)
    echo "- Solidityアーティファクト: $SOLIDITY_ARTIFACTS ファイル"
fi

# Rustバイナリ
if [ -d "target" ]; then
    RUST_BINARIES=$(find target -name "*.so" -o -name "*.a" -o -name "*.bin" 2>/dev/null | wc -l)
    echo "- Rustバイナリ: $RUST_BINARIES ファイル"
    
    # サイズ情報
    if [ "$BUILD_MODE" = "release" ]; then
        RELEASE_DIR="target/release"
        if [ -d "$RELEASE_DIR" ]; then
            echo "- リリースビルドサイズ: $(du -sh $RELEASE_DIR 2>/dev/null | cut -f1)"
        fi
    else
        DEBUG_DIR="target/debug"
        if [ -d "$DEBUG_DIR" ]; then
            echo "- デバッグビルドサイズ: $(du -sh $DEBUG_DIR 2>/dev/null | cut -f1)"
        fi
    fi
fi

echo

# ================================
# 完了メッセージ
# ================================
echo "=================================================================="
echo "Boundlessプロジェクトビルド完了！"
echo "=================================================================="
echo
echo "ビルドサマリー:"
echo "- ビルドモード: $BUILD_MODE"
echo "- 並列ジョブ数: $PARALLEL_JOBS"
echo "- RISC0_DEV_MODE: ${RISC0_DEV_MODE}"
echo
echo "次のステップ:"
echo "1. コントラクトデプロイ:"
echo "   forge create <CONTRACT_NAME> --private-key <PRIVATE_KEY> --rpc-url <RPC_URL>"
echo
echo "2. Rustバイナリ実行:"
echo "   ./target/${BUILD_MODE}/[バイナリ名]"
echo
echo "3. 開発サーバー起動:"
echo "   bun run docs  # ドキュメント"
echo
echo "4. テスト実行:"
echo "   forge test     # Solidityテスト"
echo "   cargo test     # Rustテスト"
echo
echo "便利なコマンド:"
echo "- ビルド状況確認: du -sh target/"
echo "- アーティファクト確認: ls -la out/"
echo "- 依存関係確認: cargo tree"
echo
echo "=================================================================="