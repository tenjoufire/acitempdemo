#!/bin/bash

# Azure Container Instances デプロイメントスクリプト
# Azure Deployment Environment との統合用

set -e

# 変数の設定
RESOURCE_GROUP_NAME=${1:-"rg-aci-demo"}
LOCATION=${2:-"japaneast"}
TEMPLATE_TYPE=${3:-"aci-simple"}
CONTAINER_GROUP_NAME=${4:-"aci-demo-$(date +%s)"}
ENVIRONMENT_NAME=${5:-"development"}

echo "🚀 Azure Container Instances のデプロイを開始します"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 リソースグループ: $RESOURCE_GROUP_NAME"
echo "🌍 リージョン: $LOCATION"
echo "📦 テンプレートタイプ: $TEMPLATE_TYPE"
echo "🏷️  コンテナグループ名: $CONTAINER_GROUP_NAME"
echo "🔧 環境: $ENVIRONMENT_NAME"
echo ""

# Azure CLI のログイン確認
echo "🔐 Azure 認証状態を確認中..."
if ! az account show > /dev/null 2>&1; then
    echo "❌ Azure にログインしていません"
    echo "以下のコマンドでログインしてください:"
    echo "az login"
    exit 1
fi

# サブスクリプション情報の表示
SUBSCRIPTION=$(az account show --query name -o tsv)
echo "✅ Azure サブスクリプション: $SUBSCRIPTION"
echo ""

# テンプレートタイプの検証
if [ "$TEMPLATE_TYPE" != "aci-simple" ]; then
    echo "❌ サポートされていないテンプレートタイプ: $TEMPLATE_TYPE"
    echo "利用可能なテンプレート: aci-simple"
    exit 1
fi

# リソースグループの作成または確認
echo "📂 リソースグループを確認中..."
if ! az group show --name "$RESOURCE_GROUP_NAME" > /dev/null 2>&1; then
    echo "📝 リソースグループを作成中: $RESOURCE_GROUP_NAME"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    echo "✅ リソースグループが作成されました"
else
    echo "✅ リソースグループが既に存在します"
fi
echo ""

# テンプレートファイルの確認
TEMPLATE_PATH="./templates/$TEMPLATE_TYPE/main.bicep"
PARAMETERS_PATH="./templates/$TEMPLATE_TYPE/main.parameters.json"

if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "❌ テンプレートファイルが見つかりません: $TEMPLATE_PATH"
    exit 1
fi

if [ ! -f "$PARAMETERS_PATH" ]; then
    echo "❌ パラメータファイルが見つかりません: $PARAMETERS_PATH"
    exit 1
fi

echo "📋 テンプレートファイル: $TEMPLATE_PATH"
echo "📋 パラメータファイル: $PARAMETERS_PATH"
echo ""

# デプロイメントの実行
echo "🎯 デプロイメントを実行中..."
DEPLOYMENT_NAME="aci-deployment-$(date +%Y%m%d-%H%M%S)"

# デプロイメントのプレビュー
echo "🔍 デプロイメントプレビューを実行中..."
az deployment group what-if \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "$TEMPLATE_PATH" \
    --parameters "$PARAMETERS_PATH" \
    --parameters containerGroupName="$CONTAINER_GROUP_NAME" environmentName="$ENVIRONMENT_NAME"

echo ""
read -p "⚡ デプロイメントを続行しますか? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 デプロイメントを実行中..."
    
    # 実際のデプロイメント
    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --template-file "$TEMPLATE_PATH" \
        --parameters "$PARAMETERS_PATH" \
        --parameters containerGroupName="$CONTAINER_GROUP_NAME" environmentName="$ENVIRONMENT_NAME" \
        --verbose
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 デプロイメントが正常に完了しました!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # 出力値の取得
        echo "📊 デプロイメント結果:"
        FQDN=$(az deployment group show --resource-group "$RESOURCE_GROUP_NAME" --name "$DEPLOYMENT_NAME" --query properties.outputs.fqdn.value -o tsv)
        URL=$(az deployment group show --resource-group "$RESOURCE_GROUP_NAME" --name "$DEPLOYMENT_NAME" --query properties.outputs.url.value -o tsv)
        IP_ADDRESS=$(az deployment group show --resource-group "$RESOURCE_GROUP_NAME" --name "$DEPLOYMENT_NAME" --query properties.outputs.ipAddress.value -o tsv)
        
        echo "🌐 FQDN: $FQDN"
        echo "🔗 URL: $URL"
        echo "📍 IP アドレス: $IP_ADDRESS"
        echo ""
        echo "🎯 アプリケーションにアクセスしてください: $URL"
        
        # コンテナの状態確認
        echo ""
        echo "📋 コンテナの状態:"
        az container show --resource-group "$RESOURCE_GROUP_NAME" --name "$CONTAINER_GROUP_NAME" --query instanceView.state -o table
        
    else
        echo "❌ デプロイメントに失敗しました"
        exit 1
    fi
else
    echo "⏹️  デプロイメントがキャンセルされました"
    exit 0
fi

echo ""
echo "🧹 リソースを削除するには以下のコマンドを実行してください:"
echo "az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait"
echo ""
echo "📚 ログを確認するには以下のコマンドを実行してください:"
echo "az container logs --resource-group $RESOURCE_GROUP_NAME --name $CONTAINER_GROUP_NAME"
