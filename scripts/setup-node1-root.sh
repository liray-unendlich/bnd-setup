#!/bin/bash
# ノード1（メインノード）完全セットアップスクリプト（root権限必要）
# SSH接続後、rootユーザーで実行してください

set -e

echo "=================================================================="
echo "RISC Zero Bento ノード1（メインノード） 完全セットアップスクリプト"
echo "=================================================================="
echo "このスクリプトは以下を自動実行します:"
echo "1. システムアップデート"
echo "2. 必要パッケージのインストール"
echo "3. Dockerのインストールと設定"
echo "4. ユーザー作成と権限設定"
echo "5. ファイアウォール基本設定"
echo "6. デプロイ用ディレクトリ準備"
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
    redis-tools \
    postgresql-client \
    jq \
    net-tools \
    telnet

echo "✓ 基本パッケージインストール完了"
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

# 基本ポート開放（後で詳細設定）
ufw allow 8081/tcp comment "REST API"
ufw allow 3000/tcp comment "Grafana"
ufw allow 9001/tcp comment "MinIO Console"

echo "基本ファイアウォール設定完了（詳細設定は後で実行）"
echo "✓ ファイアウォール基本設定完了"
echo

# ================================
# システム最適化設定
# ================================
echo "=== システム最適化設定中 ==="

# カーネルパラメータ調整
cat >> /etc/sysctl.conf << 'EOF'

# RISC Zero Bento最適化設定
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
  }
}
EOF

# Docker再起動
systemctl restart docker

echo "✓ Docker設定最適化完了"
echo

# ================================
# 完了メッセージと次のステップ
# ================================
echo "=================================================================="
echo "ノード1セットアップ完了！"
echo "=================================================================="
echo
echo "設定内容:"
echo "- 作業用ユーザー: $WORK_USER"
echo "- 作業ディレクトリ: $WORK_DIR"
echo "- Docker & Docker Compose: インストール済み"
echo "- 基本ファイアウォール: 設定済み"
echo "- システム最適化: 設定済み"
echo
echo "次のステップ:"
echo "1. システムを再起動してください:"
echo "   reboot"
echo
echo "2. 再起動後、作業用ユーザーでログインしてください:"
echo "   ssh $WORK_USER@[このサーバーのIP]"
echo
echo "3. 開発環境をセットアップしてください（作業用ユーザーで実行）:"
echo "   cd $WORK_DIR"
echo "   ./setup-dev-environment.sh"
echo
echo "4. プロジェクトファイルを配置してください:"
echo "   # node1-main/docker-compose.yml と .env を配置"
echo
echo "5. 詳細なファイアウォール設定を実行してください:"
echo "   ./setup-firewall-node1.sh [ノード2のIP]"
echo
echo "6. デプロイを実行してください:"
echo "   ./deploy-node1.sh"
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
echo "警告: システムを再起動するまで一部の設定は有効になりません"