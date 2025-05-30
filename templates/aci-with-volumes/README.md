# Azure Files ボリューム付き Container Instances テンプレート

このテンプレートは、Azure Files ボリュームマウント機能を持つ Azure Container Instances をデプロイします。永続化ストレージが必要なアプリケーションに最適です。

## 機能

- Azure Files 共有の自動作成
- 永続化ボリュームマウント
- ヘルスチェック（Liveness/Readiness Probe）
- リソース制限の設定
- セキュアなストレージアクセス
- 自動スケーリング対応

## アーキテクチャ

```
┌─────────────────────────────────────┐
│        Container Group              │
│  ┌─────────────────────────────────┐│
│  │      App Container              ││
│  │                                 ││
│  │  /mnt/azurefiles ← マウント      ││
│  │                                 ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│       Azure Storage Account        │
│  ┌─────────────────────────────────┐│
│  │      Azure Files Share          ││
│  │       (永続化ストレージ)        ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|-------------|------|-------------|
| `containerGroupName` | コンテナグループの名前 | `aci-volumes-{uniqueString}` |
| `containerImage` | デプロイするコンテナイメージ | `mcr.microsoft.com/azuredocs/aci-helloworld:latest` |
| `cpuCores` | CPU コア数 (1, 2, 4) | `1` |
| `memoryInGb` | メモリサイズ GB (1, 2, 4, 8) | `2` |
| `containerPort` | コンテナのポート番号 | `80` |
| `environmentName` | 環境名 | `development` |
| `storageAccountName` | ストレージアカウント名 | `acistorage{uniqueString}` |
| `fileShareName` | Azure Files 共有名 | `acifiles` |
| `mountPath` | ボリュームマウントパス | `/mnt/azurefiles` |
| `dnsNameLabel` | DNS 名ラベル | `{containerGroupName}-{uniqueString}` |
| `enableHealthCheck` | ヘルスチェック有効化 | `true` |

## 出力

- `fqdn`: コンテナグループの完全修飾ドメイン名
- `ipAddress`: パブリック IP アドレス
- `url`: アクセス可能な URL
- `storageAccountName`: 作成されたストレージアカウント名
- `fileShareName`: 作成されたファイル共有名
- `mountPath`: ボリュームマウントパス
- `resourceId`: コンテナグループのリソース ID
- `storageAccountResourceId`: ストレージアカウントのリソース ID

## デプロイ方法

### Azure CLI を使用

```bash
# リソースグループの作成
az group create --name myResourceGroup --location japaneast

# テンプレートのデプロイ
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Azure PowerShell を使用

```powershell
# リソースグループの作成
New-AzResourceGroup -Name "myResourceGroup" -Location "Japan East"

# テンプレートのデプロイ
New-AzResourceGroupDeployment `
  -ResourceGroupName "myResourceGroup" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "main.parameters.json"
```

## ユースケース

このテンプレートは以下のようなシナリオに適しています：

- **ログファイルの永続化**: アプリケーションのログを Azure Files に保存
- **設定ファイルの共有**: 複数のコンテナインスタンス間での設定共有
- **データ処理**: バッチ処理の結果を永続化ストレージに保存
- **開発環境**: 開発者間でのファイル共有環境

## セキュリティ機能

- **TLS 1.2 強制**: ストレージアカウントへの通信はTLS 1.2のみ
- **HTTPS 専用**: HTTP アクセスの無効化
- **パブリックアクセス制御**: Blob パブリックアクセスの無効化
- **アクセスキー保護**: ストレージアカウントキーの安全な管理
- **削除保護**: ファイル共有の削除保護（7日間）

## ヘルスチェック

このテンプレートには以下のヘルスチェックが含まれています：

- **Liveness Probe**: コンテナの生存確認（30秒間隔）
- **Readiness Probe**: トラフィック受信準備確認（10秒間隔）

## 監視とログ

- コンテナのイベントログを Azure Portal で確認可能
- ストレージアカウントのアクセスログ
- リソースメトリクスの監視

## カスタマイズ例

### カスタムアプリケーション用の設定

```bicep
// カスタムイメージを使用
param containerImage string = 'myregistry.azurecr.io/myapp:latest'

// 追加の環境変数
environmentVariables: [
  {
    name: 'DATABASE_CONNECTION_STRING'
    secureValue: 'your-secure-connection-string'
  }
]
```

### 複数ボリューム対応

```bicep
// 追加のボリューム定義
volumes: [
  {
    name: 'config-volume'
    azureFile: {
      shareName: 'config-share'
      storageAccountName: storageAccountName
      storageAccountKey: storageAccount.listKeys().keys[0].value
      readOnly: true
    }
  }
]
```

## トラブルシューティング

### よくある問題

1. **ボリュームマウントの失敗**
   - ストレージアカウントキーの確認
   - ファイル共有の存在確認
   - ネットワーク接続の確認

2. **ヘルスチェックの失敗**
   - アプリケーションの起動時間確認
   - ポート設定の確認
   - パス設定の確認

3. **リソース不足**
   - CPU/メモリ制限の調整
   - リージョンのクォータ確認

## 料金最適化

- 開発環境では Standard_LRS ストレージを使用
- 不要時はコンテナグループを停止
- ファイル共有のクォータを適切に設定
