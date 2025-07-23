# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**Boundless ゼロ知識証明 2サーバー分散Prover環境**

[boundless-xyz/boundless](https://github.com/boundless-xyz/boundless) の汎用ZKプロトコルをベースとした、RISC Zero Bento 2ノード分散デプロイメント環境です。

### アーキテクチャ構成
- **ノード1（メインノード・インフラサーバー）**: 
  - インフラサービス: PostgreSQL、Redis、MinIO
  - API・UI: REST API、Grafana
  - CPUコンピューティング: exec_agent、aux_agent、snark_agent
  - 推奨スペック: 16-20コア、64GB RAM、1.5TB SSD

- **ノード2（GPUクラスター・プルーフサーバー）**: 
  - GPU証明処理: gpu_prove_agent群（最大4GPU対応）
  - ゼロ知識証明生成専用
  - 推奨スペック: 8-12コア、32GB RAM、500GB SSD、複数NVIDIA GPU

## ワンラインセットアップ（推奨）

**各サーバーで以下を実行すれば、ほぼ完結します：**

### ノード1（メインノード・インフラサーバー）での実行
```bash
# 1. リポジトリクローン&環境構築
curl -fsSL https://raw.githubusercontent.com/boundless-xyz/boundless-custom/main/bento-distributed-deploy/quick-start.sh | bash

# 2. 環境変数編集（必須）
vi node1-main/.env
# POSTGRES_PASSWORD, MINIO_ROOT_PASS, PRIVATE_KEY, RPC_URL等を設定

# 3. ファイアウォール設定
./scripts/setup-firewall-node1.sh <ノード2のIP>

# 4. デプロイ実行
./scripts/deploy-node1.sh
```

### ノード2（GPUクラスター・プルーフサーバー）での実行
```bash
# 1. リポジトリクローン&環境構築
curl -fsSL https://raw.githubusercontent.com/boundless-xyz/boundless-custom/main/bento-distributed-deploy/quick-start.sh | bash

# 2. 環境変数編集（必須）
vi node2-gpu/.env
# NODE1_IPを実際のIPに変更、パスワード類をノード1と同期

# 3. ファイアウォール設定
./scripts/setup-firewall-node2.sh

# 4. デプロイ実行
./scripts/deploy-node2.sh
```

## 主要コマンド群

### RISC Zero & Boundless開発環境
```bash
# RISC Zero toolchainインストール確認
cargo risczero --version
rzup update                    # toolchain更新

# Foundryインストール確認
forge --version
foundryup                      # Foundry更新

# Boundlessプロジェクトビルド
forge build                    # Solidity contracts
cargo build --release          # Rust crates
cargo test                     # テスト実行
RISC0_DEV_MODE=1 cargo test    # 高速開発モードテスト

# ドキュメント確認
bun install && bun run docs    # http://localhost:5173
```

### 自動ビルドスクリプト
```bash
# 統合ビルドスクリプト（推奨）
./scripts/build-boundless.sh

# オプション：
# - リリース/デバッグビルド選択
# - 依存関係更新
# - テスト実行
# - ドキュメント生成
```

### Prover環境デプロイメント
```bash
# ファイアウォール設定（ネットワーク通信のため必須）
./scripts/setup-firewall-node1.sh <ノード2IP>  # ノード1: 外部+ノード2アクセス許可
./scripts/setup-firewall-node2.sh              # ノード2: SSH+GPU監視のみ

# 段階的デプロイ（推奨順序）
./scripts/deploy-node1.sh      # ノード1: インフラ起動（先に実行）
./scripts/deploy-node2.sh      # ノード2: GPU prover起動

# 一括デプロイ（設定完了済み環境）
./scripts/quick-deploy.sh      # 既存環境の再デプロイ
```

### ZK Prover 運用コマンド

#### ノード1（インフラサーバー）での操作
```bash
# サービス状態確認
docker-compose ps              # 全サービス状態
docker-compose logs -f postgres redis minio  # インフラログ
docker-compose logs -f rest_api grafana      # APIサービスログ
docker-compose logs -f exec_agent0 snark_agent # CPUエージェントログ

# パフォーマンス調整
docker-compose up -d --scale exec_agent0=4   # CPU証明エージェント追加
docker-compose --profile broker up -d        # ブローカー起動（オプション）

# インフラサービス再起動
docker-compose restart postgres redis minio
```

#### ノード2（GPU Proverサーバー）での操作
```bash
# GPU prover状態確認
docker-compose ps              # GPU agent状態
docker-compose logs -f gpu_prove_agent0     # GPU証明ログ

# マルチGPU展開
docker-compose --profile multi-gpu up -d    # 全GPU使用
docker-compose up -d --scale gpu_prove_agent0=2  # GPU0を複数インスタンス

# GPU prover再起動
docker-compose restart gpu_prove_agent0
```

### ZK証明環境の監視

#### ノード1での監視コマンド
```bash
# サービスヘルスチェック
curl http://localhost:8081/health     # REST API
curl http://localhost:3000            # Grafana dashboard
redis-cli ping                        # Redis接続確認
pg_isready -h localhost -p 5432       # PostgreSQL確認

# プルーフ処理状況
docker-compose logs exec_agent0 | grep "proof"  # CPU証明処理
docker-compose logs snark_agent | grep "snark"  # SNARK処理
```

#### ノード2での監視コマンド
```bash
# GPU使用状況（最重要）
nvidia-smi                     # GPU状態確認
watch -n 1 nvidia-smi         # リアルタイム監視
nvidia-ml-py3 --query         # 詳細GPU情報

# GPU prover処理状況
docker-compose logs gpu_prove_agent0 | grep "proof"  # GPU証明処理
docker stats $(docker-compose ps -q)  # Docker統計

# ノード1への接続確認
telnet <NODE1_IP> 5432        # PostgreSQL接続
telnet <NODE1_IP> 6379        # Redis接続  
telnet <NODE1_IP> 9000        # MinIO接続
```

#### 全体監視
```bash
# システムリソース
htop                          # CPU・メモリ
free -h                       # メモリ使用量
df -h                         # ディスク使用量
iostat 1                      # I/O統計

# ネットワーク監視
ss -tuln                      # ポートリスト
iftop                         # ネットワーク使用量（ノード間通信）
```

## ZK Prover アーキテクチャ詳細

### 2サーバー分散構成
```
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│ ノード1: インフラ + CPU証明      │  │ ノード2: GPU証明専用           │
├─────────────────────────────────┤  ├─────────────────────────────────┤
│ [外部API]                       │  │ [GPU Agents]                    │
│ • REST API :8081               │  │ • gpu_prove_agent0-3           │
│ • Grafana  :3000               │  │                                 │
│ • MinIO UI :9001               │  │ [NVIDIA GPUs]                   │
│                                 │  │ • GPU 0: CUDA compute          │
│ [インフラ]                      │  │ • GPU 1-3: Multi-GPU (opt)     │
│ • PostgreSQL :5432             │←─┤                                 │
│ • Redis      :6379             │←─┤ [Network Connection]            │
│ • MinIO      :9000             │←─┤ • 暗号化されたZK証明データ送受信 │
│                                 │  │ • ファイアウォール制御済み      │
│ [CPU Agents]                    │  │                                 │
│ • exec_agent0/1: 実行証明       │  └─────────────────────────────────┘
│ • aux_agent: 補助処理           │
│ • snark_agent: SNARK生成        │
│                                 │
│ [Broker] (Optional)             │
│ • ブロックチェーン連携           │
└─────────────────────────────────┘
```

### ディレクトリ構造と役割
```
bento-distributed-deploy/
├── node1-main/           # ノード1: インフラ + CPU証明
│   ├── docker-compose.yml   # 全インフラ + CPU agents
│   ├── .env                 # DB/MinIO/秘密鍵設定
│   └── broker.toml.example  # ブローカー設定
├── node2-gpu/            # ノード2: GPU証明専用
│   ├── docker-compose.yml   # GPU agents only
│   └── .env                 # NODE1_IP + 認証情報
├── scripts/              # デプロイ自動化
│   ├── setup-*-root.sh      # システム環境構築
│   ├── setup-dev-environment.sh  # RISC Zero toolchain
│   ├── build-boundless.sh   # Boundless プロジェクトビルド
│   ├── deploy-node*.sh      # サービスデプロイ
│   └── setup-firewall-*.sh  # ネットワーク設定
└── docs/                 # 運用ドキュメント
```

### ZK証明フロー
1. **タスク受信**: REST API → PostgreSQL → Redis キュー
2. **CPU前処理**: exec_agent → 実行環境セットアップ
3. **GPU証明生成**: ノード2 gpu_prove_agent → RISC Zero証明
4. **SNARK変換**: snark_agent → 最終証明生成
5. **結果保存**: PostgreSQL + MinIO → REST API応答

### 重要な設定ファイル

#### ノード1設定 (`node1-main/.env`)
```bash
# データベース認証
POSTGRES_PASSWORD=<強固なパスワード>
POSTGRES_USER=worker
POSTGRES_DB=taskdb

# ストレージ認証  
MINIO_ROOT_PASS=<強固なパスワード>
MINIO_ROOT_USER=admin

# ブローカー設定（ブロックチェーン連携）
PRIVATE_KEY=<秘密鍵>
RPC_URL=<RPCエンドポイント>
BOUNDLESS_MARKET_ADDRESS=<コントラクトアドレス>
```

#### ノード2設定 (`node2-gpu/.env`)
```bash
# ノード1接続設定（必須）
NODE1_IP=192.168.1.100  # 実際のIPに変更

# 認証情報（ノード1と同期）
POSTGRES_PASSWORD=<ノード1と同じ>
MINIO_ROOT_PASS=<ノード1と同じ>

# GPU最適化
CUDA_VISIBLE_DEVICES=0,1,2,3  # 使用GPU指定
```

### ネットワーク設定（ファイアウォール制御済み）
| サービス | ポート | 接続元 | 用途 |
|---------|-------|-------|------|
| **外部公開** |
| REST API | 8081 | 外部 | ZK証明API |
| Grafana | 3000 | 外部 | 監視ダッシュボード |
| MinIO Console | 9001 | 外部 | ストレージ管理 |
| **ノード間通信** |
| PostgreSQL | 5432 | ノード2 | ZK証明データ |
| Redis | 6379 | ノード2 | タスクキュー |
| MinIO | 9000 | ノード2 | 証明結果保存 |
| **管理用** |
| SSH | 22 | 管理者 | リモートアクセス |
| GPU監視 | 3333 | 管理者 | GPU状態監視（opt) |

## ZK Prover 運用上の重要ポイント

### セキュリティ要件
- **秘密鍵管理**: `PRIVATE_KEY`は暗号化保存、定期ローテーション
- **データベース**: `POSTGRES_PASSWORD`は32文字以上の強固なパスワード
- **ネットワーク**: ファイアウォール設定により不要ポート封鎖済み
- **ファイル権限**: `.env`ファイルは `600` 権限で保護

### GPU環境の最適化
- **NVIDIA設定**: Container Toolkit + CUDA 12.2 ドライバー必須
- **GPU割り当て**: `device_ids`で明示的GPU指定（競合回避）
- **メモリ管理**: GPU証明時に大量VRAM使用（8GB+推奨）
- **温度監視**: `nvidia-smi`で GPU温度を定期確認

### パフォーマンスチューニング
```bash
# CPU証明エージェント数の動的調整
docker-compose up -d --scale exec_agent0=$(nproc)

# GPU証明の並列度調整（GPUメモリに応じて）
docker-compose up -d --scale gpu_prove_agent0=2  # 大容量GPU用

# メモリ制限の環境別調整
# node1-main/docker-compose.yml の mem_limit を編集
```

### ZK証明キューの監視
```bash
# Redis証明キュー状況確認
redis-cli LLEN proof_queue         # 待機中証明数
redis-cli LLEN exec_queue          # 実行待ちタスク数

# PostgreSQL証明履歴確認
docker-compose exec postgres psql -U worker -d taskdb -c "SELECT * FROM proof_jobs LIMIT 10;"
```

### 障害対応とバックアップ
```bash
# 証明データベースバックアップ（定期実行推奨）
docker-compose exec postgres pg_dump -U worker taskdb > zk_proofs_backup_$(date +%Y%m%d).sql

# MinIO証明結果バックアップ
docker run --rm -v minio-data:/data -v $(pwd):/backup alpine tar czf /backup/zk_proof_results_$(date +%Y%m%d).tar.gz /data

# システム状態スナップショット
docker-compose ps > system_status_$(date +%Y%m%d_%H%M).log
nvidia-smi >> system_status_$(date +%Y%m%d_%H%M).log
```

### トラブルシューティング

#### よくある問題
1. **GPU証明が開始されない**: ノード1→ノード2のネットワーク接続確認
2. **証明処理が遅い**: GPU温度スロットリング、VRAM不足を確認
3. **接続エラー**: `.env`のNODE1_IP設定とファイアウォール設定を確認

#### 緊急時対応
```bash
# 全サービス緊急停止
docker-compose down                # 各ノードで実行

# 証明データのみ安全停止
docker-compose stop gpu_prove_agent0  # GPU証明のみ停止
docker-compose stop exec_agent0       # CPU証明のみ停止

# インフラサービスは維持したまま証明エージェントのみ再起動
docker-compose restart exec_agent0 snark_agent gpu_prove_agent0
```

### boundless-xyz/boundless統合時の注意
- **ライセンス**: 本番使用時はBusiness Source Licenseに注意
- **バージョン互換性**: RISC Zero toolchainとBoundless SDKのバージョン同期
- **契約アドレス**: `BOUNDLESS_MARKET_ADDRESS`はネットワーク別に設定