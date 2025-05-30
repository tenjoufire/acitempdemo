# シンプルな Azure Container Instances テンプレート

このテンプレートは、Azure Container Instances を使用してシンプルなコンテナアプリケーションをデプロイします。

## 機能

- 単一コンテナのデプロイメント
- パブリック IP アドレスの自動割り当て
- DNS 名の自動生成
- 環境変数の設定
- セキュアな設定

## パラメータ

| パラメータ名 | 説明 | デフォルト値 |
|-------------|------|-------------|
| `containerGroupName` | コンテナグループの名前 | `aci-{uniqueString}` |
| `containerImage` | デプロイするコンテナイメージ | `mcr.microsoft.com/azuredocs/aci-helloworld:latest` |
| `cpuCores` | CPU コア数 (1, 2, 4) | `1` |
| `memoryInGb` | メモリサイズ GB (1, 2, 4, 8) | `1` |
| `containerPort` | コンテナのポート番号 | `80` |
| `environmentName` | 環境名 | `development` |
| `ipAddressType` | IP アドレスタイプ (Public/Private) | `Public` |
| `dnsNameLabel` | DNS 名ラベル | `{containerGroupName}-{uniqueString}` |

## 出力

- `fqdn`: コンテナグループの完全修飾ドメイン名
- `ipAddress`: パブリック IP アドレス
- `url`: アクセス可能な URL
- `resourceId`: リソース ID

## デプロイ方法

### Azure CLI を使用

```bash
az deployment group create \
  --resource-group myResourceGroup \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Azure PowerShell を使用

```powershell
New-AzResourceGroupDeployment `
  -ResourceGroupName "myResourceGroup" `
  -TemplateFile "main.bicep" `
  -TemplateParameterFile "main.parameters.json"
```

## セキュリティ考慮事項

- コンテナイメージは信頼できるレジストリから取得
- 機密情報は環境変数ではなく Azure Key Vault を使用することを推奨
- 本番環境では Private IP アドレスの使用を検討

## カスタマイズ

このテンプレートは基本的な設定を提供します。追加の機能が必要な場合は：

- ボリュームマウント
- ヘルスチェック
- 複数コンテナ
- カスタムネットワーク設定

などを追加できます。
