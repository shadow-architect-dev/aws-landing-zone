# AWS Transit Gateway (TGW) 閉域ネットワーク接続仕様書

本仕様書は、`aws-landing-zone`（プラットフォーム側）から共有される AWS Transit Gateway (TGW) を用いて、各ワークロードアカウント（ECS/EKS）の VPC を接続するための手順および実装サンプルを定義したものです。

---

## 📌 アーキテクチャ概要

各環境の VPC（Spoke）を、Shared Services アカウントに構築された TGW（Hub）へアタッチします。これにより、環境間またはオンプレミス接続、あるいは集約型の VPC エンドポイントを介した閉域通信が可能になります。

```text
       [ Log Archive ]
              ▲
              │ (Firehose/S3 Logs)
[ ECS (CDK) ] ┼─► [ Transit Gateway (Hub) ] ◄─┼ [ EKS (Terraform) ]
  (Spoke)     │                               │     (Spoke)
              ▼                               ▼
      VPC Attachment                  VPC Attachment
```

---

## 🔑 前提条件

1.  プラットフォーム側で TGW および AWS RAM による組織共有設定が完了していること。
2.  接続先の TGW ID が、各リポジトリに同期されていること。
    *   TGW ID: `tgw-XXXXXXXXXXXXXXXXX`
    *   TGW 共有オーナーアカウント ID (Shared Services): `444444444444` (例)

---

## 🛠️ 個別リポジトリ側の接続実装サンプル

### A. EKS 側 (Terraform / HCL) での実装例
`learning-terraform-concepts` 等の Terraform コードベースで、TGW アタッチメントと VPC ルートを追加します。

#### 1. TGW アタッチメントの定義
VPC のプライベートサブネット群を指定し、共有された TGW へのアタッチメントを作成します。

```hcl
# 共有されている TGW リソースを参照 (Data Source)
data "aws_ec2_transit_gateway" "shared" {
  id = var.transit_gateway_id # プラットフォーム側から同期された TGW ID
}

# TGW VPC アタッチメントの作成
resource "aws_ec2_transit_gateway_vpc_attachment" "eks_tgw" {
  transit_gateway_id = data.aws_ec2_transit_gateway.shared.id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  # 自動承認を有効にしているため、アタッチメント作成後に即時疎通します
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name = "${var.cluster_name}-tgw-attachment"
  }
}
```

#### 2. サブネットルートテーブルへの TGW ルート追加
Spoke 側の VPC ルートテーブルに、特定の閉域宛て（または他環境宛て）の通信を TGW へ転送するルートを追加します。

```hcl
# プライベートサブネットから TGW 宛てのルート定義
resource "aws_route" "to_tgw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8" # 組織内共通のIP範囲 (例)
  transit_gateway_id     = data.aws_ec2_transit_gateway.shared.id
}
```

---

### B. ECS 側 (TypeScript & AWS CDK) での実装例
`learning-ts-concepts` などの CDK コードベースで、CFN L1 リソースを用いてアタッチメントおよびルートを実装します。

#### 1. TGW アタッチメントの定義 (`compute.ts` 等)
```typescript
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export interface TgwAttachmentProps {
  readonly vpc: ec2.IVpc;
  readonly tgwId: string;
}

export class TgwAttachment extends Construct {
  constructor(scope: Construct, id: string, props: TgwAttachmentProps) {
    super(scope, id);

    // TGW VPC アタッチメントのプロビジョニング (L1 Resource)
    const tgwAttachment = new ec2.CfnTransitGatewayAttachment(this, 'TgwVpcAttachment', {
      transitGatewayId: props.tgwId,
      vpcId: props.vpc.vpcId,
      // アタッチメントを配置するプライベートサブネットを指定
      subnetIds: props.vpc.selectSubnets({ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS }).subnetIds,
      tags: [{
        key: 'Name',
        value: `${cdk.Stack.of(this).stackName}-tgw-attachment`,
      }],
    });
  }
}
```

#### 2. サブネットルートテーブルへの TGW ルート追加
CDK VPC を使用している場合、プライベートサブネットのルートテーブルを取得し、CfnRoute をアタッチします。

```typescript
const privateSubnets = props.vpc.selectSubnets({ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS });

privateSubnets.subnets.forEach((subnet, index) => {
  new ec2.CfnRoute(this, `RouteToTgw-${index}`, {
    routeTableId: subnet.routeTable.routeTableId,
    destinationCidrBlock: '10.0.0.0/8', // 組織内閉域宛てのCIDRブロック
    transitGatewayId: props.tgwId,
  });
});
```

---

## 🔍 検証および接続フロー

1.  **インフラ合成・テスト**:
    *   EKS側: `terraform plan` を実行し、`aws_ec2_transit_gateway_vpc_attachment` が正しく作成されることを検証。
    *   ECS/CDK側: `npm test` または `cdk synth` を実行し、CloudFormation テンプレートの合成エラーがないことを検証。
2.  **AWS RAM の共有承認**:
    *   Spoke 側のアカウントで、AWS RAM ➔ Shared with me ➔ Resource shares を開き、プラットフォーム側から共有されているリソース（`transit-gateway-share`）を承認します（Organizations内共有の場合は自動承認されます）。
3.  **アタッチメントのステータス確認**:
    *   VPC ➔ Transit gateway attachments を確認し、ステータスが `available` であることを確認。
4.  **双方向疎通テスト**:
    *   Spoke 側のインスタンス/コンテナから、`Shared Services` に配置された共通エンドポイントや、他 VPC 内のサーバーへ `ping` または `curl` で疎通ができることを確認。

---

## ⚠️ 設計時の注意事項（SREベストプラクティス）

*   **CIDR 重複の厳禁 (警告: 現在の競合状況)**:
    Spoke VPC 同士で IP アドレスの重複があると、TGW でルートが競合してパケットがドロップします。
    **実地調査結果による競合の警告**:
    - `learning-terraform-concepts` (EKS/dev): `10.0.0.0/16`
    - `learning-ts-concepts` (ECS/CDK/dev): `10.0.0.0/16`
    上記のように、現在双方のプロジェクトの開発環境 (`dev`) において **`10.0.0.0/16` が完全に重複しています**。
    このまま TGW に接続するとルート競合を引き起こすため、開発環境を TGW にアタッチする前に、どちらか一方（または双方）の VPC CIDR を一意なアドレス（例：CDK-dev 側を `10.10.0.0/16`、EKS-dev 側を `10.20.0.0/16` など）へリプラニング（再割り当て）する必要があります。本番（`prod`）や検証（`stg`）では、本 Landing Zone で設計された IP レンジ（例: `10.1.0.0/16`, `10.2.0.0/16` など）に沿って重複のないようにプロビジョニングしてください。
*   **不要な Egress の制限**: Spoke 側で TGW を経由させるルートを追加する際、セキュリティグループや NACL で必要なポート（例: Datadog 送信用の特定ポート、DNS/エンドポイントポート）のみを許可する最小権限ルール（Principle of Least Privilege）を徹底してください。
