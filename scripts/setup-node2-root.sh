#!/bin/bash
# ノード2（GPUノード）完全セットアップスクリプト（root権限必要）
# SSH接続後、rootユーザーで実行してください

set -e

echo "=================================================================="
echo "RISC Zero Bento ノード2（GPUノード） 完全セットアップスクリプト"
echo "=================================================================="
echo "このスクリプトは以下を自動実行します:"
echo "1. システムアップデート"
echo "2. 必要パッケージのインストール"
echo "3. NVIDIA ドライバーのインストール確認"
echo "4. Dockerのインストールと設定"
echo "5. NVIDIA Container Toolkitのインストール"
echo "6. ユーザー作成と権限設定"
echo "7. ファイアウォール基本設定"
echo "8. デプロイ用ディレクトリ準備"
echo "=================================================================="
echo

# rootユーザーチェック
if [ "$EUID" -ne 0 ]; then
    echo "エラー: このスクリプトはrootユーザーで実行してください"
    echo "実行方法: sudo $0"
    exit 1
fi

# OS確認
if [ ! -f /etc/os-release ]; then
    echo "エラー: サポートされていないOSです"
    exit 1
fi

source /etc/os-release
echo "検出されたOS: $PRETTY_NAME"

# Ubuntu/Debian系のみサポート
if [[ ! "$ID" =~ ^(ubuntu|debian)$ ]]; then
    echo "警告: このスクリプトはUbuntu/Debian系でテストされています"
    read -p "続行しますか？ [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ユーザー名の設定
read -p "作業用ユーザー名を入力してください [bento]: " WORK_USER
WORK_USER=${WORK_USER:-bento}
echo "作業用ユーザー: $WORK_USER"
echo

# ================================
# システムアップデート
# ================================
echo "=== システムアップデート実行中 ==="
apt-get update -y
apt-get upgrade -y
echo "✓ システムアップデート完了"
echo

# ================================
# 必要パッケージインストール
# ================================
echo "=== 基本パッケージインストール中 ==="
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    jq \
    net-tools \
    telnet \
    build-essential \
    dkms

echo "✓ 基本パッケージインストール完了"
echo

# ================================
# NVIDIA ドライバー確認・インストール
# ================================
echo "=== NVIDIA ドライバー確認中 ==="

if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA ドライバーが既にインストールされています"
    nvidia-smi
else
    echo "NVIDIA ドライバーがインストールされていません"
    
    # GPUの検出
    if lspci | grep -i nvidia > /dev/null; then
        echo "NVIDIA GPUが検出されました:"
        lspci | grep -i nvidia
        echo
        
        read -p "NVIDIA ドライバーを自動インストールしますか？ [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "NVIDIA ドライバーインストール中..."
            
            # Ubuntu用の推奨ドライバーインストール
            ubuntu-drivers autoinstall
            
            echo "✓ NVIDIA ドライバーインストール完了"
            echo "注意: ドライバーインストール後はシステム再起動が必要です"
        else
            echo "警告: NVIDIA ドライバーがインストールされていません"
            echo "手動でインストールしてからこのスクリプトを再実行してください"
        fi
    else
        echo "警告: NVIDIA GPUが検出されませんでした"
        echo "GPUが正しく接続されているか確認してください"
        read -p "続行しますか？ [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi
echo

# ================================
# Dockerインストール
# ================================
echo "=== Docker & Docker Composeインストール中 ==="

# 既存のDockerを削除
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Dockerの公式GPGキー追加
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Dockerリポジトリ追加
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# パッケージ更新とDockerインストール
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Dockerサービス開始・自動起動設定
systemctl start docker
systemctl enable docker

# Docker Composeスタンドアロン版もインストール（互換性のため）
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "✓ Docker & Docker Composeインストール完了"
docker --version
docker-compose --version
echo

# ================================
# NVIDIA Container Toolkitインストール
# ================================
echo "=== NVIDIA Container Toolkitインストール中 ==="

# NVIDIA Container Toolkit リポジトリ設定
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

# インストール
apt-get update -y
apt-get install -y nvidia-container-toolkit

# Docker設定更新
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "✓ NVIDIA Container Toolkitインストール完了"

# GPUテスト
if command -v nvidia-smi &> /dev/null; then
    echo "=== GPU動作テスト実行中 ==="
    if docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi; then
        echo "✓ GPU動作テスト成功"
    else
        echo "✗ GPU動作テスト失敗"
        echo "システム再起動後に再テストしてください"
    fi
else
    echo "nvidia-smiが利用できません。システム再起動後に確認してください"
fi
echo

# ================================
# ユーザー作成と設定
# ================================
echo "=== 作業用ユーザー設定中 ==="

# ユーザー作成（既存の場合はスキップ）
if id "$WORK_USER" &>/dev/null; then
    echo "ユーザー $WORK_USER は既に存在します"
else
    useradd -m -s /bin/bash "$WORK_USER"
    echo "ユーザー $WORK_USER を作成しました"
fi

# Dockerグループに追加
usermod -aG docker "$WORK_USER"
echo "✓ ユーザー $WORK_USER をdockerグループに追加"

# sudoers設定（パスワードなしsudo）
echo "$WORK_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$WORK_USER
echo "✓ sudoers設定完了"

# SSH公開鍵設定（オプション）
read -p "SSH公開鍵を設定しますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    USER_HOME="/home/$WORK_USER"
    mkdir -p "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    
    echo "SSH公開鍵を入力してください（1行で入力）:"
    read -r SSH_PUBLIC_KEY
    
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "$SSH_PUBLIC_KEY" > "$USER_HOME/.ssh/authorized_keys"
        chmod 600 "$USER_HOME/.ssh/authorized_keys"
        chown -R "$WORK_USER:$WORK_USER" "$USER_HOME/.ssh"
        echo "✓ SSH公開鍵設定完了"
    fi
fi

echo

# ================================
# 作業ディレクトリ準備
# ================================
echo "=== 作業ディレクトリ準備中 ==="

WORK_DIR="/opt/boundless-custom"
mkdir -p "$WORK_DIR"
chown "$WORK_USER:$WORK_USER" "$WORK_DIR"

# GitHubリポジトリクローン（オプション）
read -p "GitHubからプロジェクトファイルをクローンしますか？ [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "GitHubリポジトリをクローン中..."
    cd "$WORK_DIR"
    
    # 既存のboundless-customディレクトリがある場合は削除
    if [ -d "boundless-custom" ]; then
        rm -rf boundless-custom
    fi
    
    # リポジトリクローン（実際のリポジトリURLに変更してください）
    if sudo -u "$WORK_USER" git clone https://github.com/boundless-xyz/boundless-custom.git; then
        echo "✓ GitHubクローン完了"
        chown -R "$WORK_USER:$WORK_USER" boundless-custom
    else
        echo "⚠ GitHubクローンに失敗しました（手動でファイルを配置してください）"
    fi
else
    echo "GitHubクローンをスキップしました"
fi

echo "作業ディレクトリ: $WORK_DIR"
echo "✓ 作業ディレクトリ準備完了"
echo

# ================================
# ファイアウォール基本設定
# ================================
echo "=== ファイアウォール基本設定中 ==="

# UFWリセット
ufw --force reset

# デフォルトポリシー設定
ufw default deny incoming
ufw default allow outgoing

# SSH許可
ufw allow ssh

echo "基本ファイアウォール設定完了（GPUノードは外部ポート不要）"
echo "✓ ファイアウォール基本設定完了"
echo

# ================================
# システム最適化設定
# ================================
echo "=== システム最適化設定中 ==="

# カーネルパラメータ調整
cat >> /etc/sysctl.conf << 'EOF'

# RISC Zero Bento GPU最適化設定
vm.max_map_count=262144
fs.file-max=65536
net.core.somaxconn=65535
net.ipv4.ip_local_port_range=1024 65535
EOF

# 制限値調整
cat >> /etc/security/limits.conf << 'EOF'

# RISC Zero Bento制限値設定
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# 設定適用
sysctl -p

echo "✓ システム最適化設定完了"
echo

# ================================
# Docker設定最適化
# ================================
echo "=== Docker設定最適化中 ==="

# Dockerデーモン設定
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Hard": 65536,
      "Name": "nofile",
      "Soft": 65536
    }
  },
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia"
}
EOF

# Docker再起動
systemctl restart docker

echo "✓ Docker設定最適化完了"
echo

# ================================
# GPU監視ツールインストール（オプション）
# ================================
echo "=== GPU監視ツールインストール中 ==="

# nvtopインストール（GPU監視ツール）
if [[ "$ID" == "ubuntu" ]]; then
    apt-get install -y nvtop 2>/dev/null || {
        echo "nvtopのインストールに失敗しました（オプション機能のためスキップ）"
    }
fi

echo "✓ GPU監視ツール設定完了"
echo

# ================================
# 完了メッセージと次のステップ
# ================================
echo "=================================================================="
echo "ノード2（GPU）セットアップ完了！"
echo "=================================================================="
echo
echo "設定内容:"
echo "- 作業用ユーザー: $WORK_USER"
echo "- 作業ディレクトリ: $WORK_DIR"
echo "- Docker & Docker Compose: インストール済み"
echo "- NVIDIA Container Toolkit: インストール済み"
echo "- 基本ファイアウォール: 設定済み"
echo "- システム最適化: 設定済み"
echo

# GPU情報表示
if command -v nvidia-smi &> /dev/null; then
    echo "GPU情報:"
    nvidia-smi -L
else
    echo "GPU情報: システム再起動後に確認してください"
fi
echo

echo "次のステップ:"
echo "1. システムを再起動してください:"
echo "   reboot"
echo
echo "2. 再起動後、作業用ユーザーでログインしてください:"
echo "   ssh $WORK_USER@[このサーバーのIP]"
echo
echo "3. GPU動作確認を実行してください:"
echo "   docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi"
echo
echo "4. プロジェクトファイルを配置してください:"
echo "   cd $WORK_DIR"
echo "   # node2-gpu/docker-compose.yml と .env を配置"
echo "   # .env の NODE1_IP を実際のノード1のIPに設定"
echo
echo "5. ファイアウォール設定を実行してください:"
echo "   ./setup-firewall-node2.sh"
echo
echo "6. デプロイを実行してください:"
echo "   ./deploy-node2.sh"
echo
echo "=================================================================="

# システム情報表示
echo "システム情報:"
echo "- OS: $PRETTY_NAME"
echo "- CPU: $(nproc) cores"
echo "- Memory: $(free -h | awk '/^Mem:/ {print $2}')"
echo "- Disk: $(df -h / | awk 'NR==2 {print $2 " (available: " $4 ")"}')"
echo "- Docker: $(docker --version)"
echo "- Docker Compose: $(docker-compose --version)"

echo
echo "重要: システムを再起動するまで一部の設定（特にGPU関連）は有効になりません"