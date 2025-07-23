#!/bin/bash
# Boundless開発環境セットアップスクリプト
# Rust, RISC Zero toolchain, Foundry, 必要な依存関係をインストール

set -e

echo "=================================================================="
echo "Boundless 開発環境セットアップスクリプト"
echo "=================================================================="
echo "このスクリプトは以下をインストールします:"
echo "1. Rust and rustup"
echo "2. RISC Zero toolchain" 
echo "3. Foundry (forge, cast, anvil, chisel)"
echo "4. Node.js and bun (ドキュメント用)"
echo "5. 追加の開発ツール"
echo "=================================================================="
echo

# ユーザー権限チェック（rootでない方が良い場合が多い）
if [ "$EUID" -eq 0 ]; then
    echo "警告: このスクリプトはrootユーザーで実行されています"
    echo "Rust/Foundryは通常一般ユーザーでインストールします"
    read -p "続行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ワーキングディレクトリ設定
WORK_DIR="${1:-$PWD}"
if [ ! -d "$WORK_DIR" ]; then
    echo "ワーキングディレクトリを作成: $WORK_DIR"
    mkdir -p "$WORK_DIR"
fi

cd "$WORK_DIR"
echo "ワーキングディレクトリ: $PWD"
echo

# ================================
# 基本ツールのインストール
# ================================
echo "=== 基本ツールのインストール ==="

# OS検出
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    sudo apt-get update
    sudo apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        libssl-dev \
        pkg-config \
        clang \
        cmake \
        libudev-dev \
        protobuf-compiler
elif command -v yum &> /dev/null; then
    # RHEL/CentOS
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y \
        curl \
        wget \
        git \
        openssl-devel \
        pkg-config \
        clang \
        cmake \
        systemd-devel \
        protobuf-compiler
elif command -v brew &> /dev/null; then
    # macOS
    brew install \
        git \
        cmake \
        protobuf
else
    echo "警告: サポートされていないパッケージマネージャーです"
    echo "手動で必要なパッケージをインストールしてください"
fi

echo "✓ 基本ツールインストール完了"
echo

# ================================
# Rustインストール
# ================================
echo "=== Rustインストール ==="

if command -v rustc &> /dev/null; then
    echo "Rustは既にインストールされています"
    rustc --version
    cargo --version
else
    echo "Rustをインストール中..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    echo "✓ Rustインストール完了"
fi

# Rustコンポーネント追加
echo "Rustコンポーネントを更新中..."
rustup update
rustup component add clippy rustfmt

# WebAssemblyターゲット追加
rustup target add wasm32-unknown-unknown

echo "✓ Rustセットアップ完了"
echo

# ================================
# RISC Zero toolchainインストール
# ================================
echo "=== RISC Zero toolchainインストール ==="

if command -v cargo-risczero &> /dev/null; then
    echo "RISC Zero toolchainは既にインストールされています"
    cargo risczero --version
else
    echo "RISC Zero toolchainをインストール中..."
    
    # rzupインストール
    curl -L https://risczero.com/install | bash
    
    # PATHに追加（現在のセッション用）
    export PATH="$HOME/.local/bin:$PATH"
    
    # rzupを使ってtoolchainインストール
    if command -v rzup &> /dev/null; then
        rzup install
    else
        # 代替方法
        cargo install cargo-risczero
        cargo risczero install
    fi
    
    echo "✓ RISC Zero toolchainインストール完了"
fi

# 動作確認
echo "RISC Zero toolchain確認中..."
if cargo risczero --version; then
    echo "✓ RISC Zero toolchain動作確認完了"
else
    echo "⚠ RISC Zero toolchainの確認に失敗しました"
    echo "シェル再起動後に再確認してください"
fi
echo

# ================================
# Foundryインストール
# ================================
echo "=== Foundryインストール ==="

if command -v forge &> /dev/null; then
    echo "Foundryは既にインストールされています"
    forge --version
    cast --version
else
    echo "Foundryをインストール中..."
    curl -L https://foundry.paradigm.xyz | bash
    
    # PATHに追加（現在のセッション用）
    export PATH="$HOME/.foundry/bin:$PATH"
    
    # foundryup実行
    if command -v foundryup &> /dev/null; then
        foundryup
    else
        echo "⚠ foundryupが見つかりません。シェル再起動後に'foundryup'を実行してください"
    fi
    
    echo "✓ Foundryインストール完了"
fi

# 動作確認
echo "Foundry確認中..."
if command -v forge &> /dev/null && command -v cast &> /dev/null; then
    forge --version
    cast --version
    echo "✓ Foundry動作確認完了"
else
    echo "⚠ Foundryの確認に失敗しました"
    echo "シェル再起動後に再確認してください"
fi
echo

# ================================
# Node.js and bunインストール（オプション）
# ================================
echo "=== Node.js and bunインストール（ドキュメント用） ==="

read -p "Node.js and bunをインストールしますか？（ドキュメント生成用） [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Node.jsインストール（nvmを使用）
    if command -v node &> /dev/null; then
        echo "Node.jsは既にインストールされています"
        node --version
    else
        echo "Node.jsをインストール中..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
        
        # nvm経由でNode.js LTSインストール
        if command -v nvm &> /dev/null; then
            nvm install --lts
            nvm use --lts
        else
            echo "⚠ nvmのセットアップに失敗しました。シェル再起動後に設定してください"
        fi
    fi
    
    # bunインストール
    if command -v bun &> /dev/null; then
        echo "bunは既にインストールされています"
        bun --version
    else
        echo "bunをインストール中..."
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
        
        if command -v bun &> /dev/null; then
            bun --version
            echo "✓ bunインストール完了"
        else
            echo "⚠ bunのインストールに失敗しました"
        fi
    fi
else
    echo "Node.js/bunのインストールをスキップしました"
fi
echo

# ================================
# 環境変数設定ファイル更新
# ================================
echo "=== 環境変数設定更新 ==="

# .bashrc/.zshrc更新
SHELL_RC="$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

echo "シェル設定ファイル: $SHELL_RC"

# 必要なパス設定を追加
cat >> "$SHELL_RC" << 'EOF'

# Boundless開発環境設定
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.foundry/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"

# RISC Zero環境変数
export RISC0_DEV_MODE=1
EOF

echo "✓ 環境変数設定更新完了"
echo

# ================================
# Boundlessプロジェクトクローン（オプション）
# ================================
echo "=== Boundlessプロジェクトセットアップ ==="

read -p "Boundlessプロジェクトをクローンしますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "boundless" ]; then
        echo "boundlessディレクトリは既に存在します"
        cd boundless
        git pull
    else
        echo "Boundlessプロジェクトをクローン中..."
        git clone https://github.com/boundless-xyz/boundless.git
        cd boundless
    fi
    
    echo "プロジェクトディレクトリ: $PWD"
    echo "✓ Boundlessプロジェクトセットアップ完了"
else
    echo "プロジェクトクローンをスキップしました"
fi
echo

# ================================
# 完了メッセージ
# ================================
echo "=================================================================="
echo "開発環境セットアップ完了！"
echo "=================================================================="
echo
echo "インストールされたツール:"
echo "- Rust: $(rustc --version 2>/dev/null || echo '要シェル再起動')"
echo "- Cargo: $(cargo --version 2>/dev/null || echo '要シェル再起動')"
echo "- RISC Zero: $(cargo risczero --version 2>/dev/null || echo '要シェル再起動')"
echo "- Forge: $(forge --version 2>/dev/null || echo '要シェル再起動')"
echo "- Cast: $(cast --version 2>/dev/null || echo '要シェル再起動')"

if command -v node &> /dev/null; then
    echo "- Node.js: $(node --version)"
fi

if command -v bun &> /dev/null; then
    echo "- Bun: $(bun --version)"
fi

echo
echo "次のステップ:"
echo "1. シェルを再起動するか、以下を実行:"
echo "   source ~/.bashrc  # または source ~/.zshrc"
echo
echo "2. Boundlessプロジェクトでビルド実行:"
echo "   cd boundless"  
echo "   forge build      # Solidityコントラクト"
echo "   cargo build      # Rustクレート"
echo
echo "3. ドキュメント生成（オプション）:"
echo "   bun install"
echo "   bun run docs"
echo "   # http://localhost:5173 でアクセス"
echo
echo "4. RISC Zero開発モード有効化済み:"
echo "   export RISC0_DEV_MODE=1"
echo
echo "=================================================================="

# 最終確認用スクリプト生成
cat > check-dev-env.sh << 'EOF'
#!/bin/bash
echo "=== 開発環境確認 ==="
echo -n "Rust: "; rustc --version 2>/dev/null || echo "未インストール"
echo -n "Cargo: "; cargo --version 2>/dev/null || echo "未インストール"  
echo -n "RISC Zero: "; cargo risczero --version 2>/dev/null || echo "未インストール"
echo -n "Forge: "; forge --version 2>/dev/null || echo "未インストール"
echo -n "Cast: "; cast --version 2>/dev/null || echo "未インストール"
echo -n "Node.js: "; node --version 2>/dev/null || echo "未インストール"
echo -n "Bun: "; bun --version 2>/dev/null || echo "未インストール"
echo "環境変数RISC0_DEV_MODE: ${RISC0_DEV_MODE:-未設定}"
EOF

chmod +x check-dev-env.sh
echo "確認用スクリプトを生成しました: ./check-dev-env.sh"