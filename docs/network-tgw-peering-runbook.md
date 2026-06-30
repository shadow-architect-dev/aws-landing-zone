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

### 🌐 全アカウント共通 VPC CIDR管理台帳

マルチアカウント全体のネットワーク設計整合性を維持し、IPアドレス重複（競合）による TGW ルーティング障害を防ぐため、以下の割り当て台帳（ルール）に従って各 VPC を構築してください。

| システム / アカウント | 環境 (Environment) | 割り当てCIDRブロック | 備考 |
| :--- | :--- | :--- | :--- |
| **Shared Services** | 共通 (Shared) | `10.0.0.0/16` | 既存構成 |
| **EKS** (learning-terraform-concepts) | dev | **`10.10.0.0/16`** | ★重複回避のため新規割り当て |
| | stg | `10.1.0.0/16` | 既存構成 |
| | prod | `10.2.0.0/16` | 既存構成 |
| **ECS** (learning-ts-concepts) | dev | **`10.20.0.0/16`** | ★重複回避のため新規割り当て |
| | stg | **`10.21.0.0/16`** | ★将来の衝突予防用 |
| | prod | **`10.22.0.0/16`** | ★将来の衝突予防用 |

> [!WARNING]
> 個別リポジトリ側で VPC を初期構築または修正する際は、必ず上記台帳に指定された CIDR ブロックを使用してください。特に `dev` 環境における旧設定 `10.0.0.0/16` は、TGW ルーティングが破綻するため利用禁止とします。

### 🏷️ AWS VPC IPAM (IP Address Manager) による自動アロケーション

本プロジェクトでは、静的な IP 割り当てに加えて、**AWS VPC IPAM** をプロビジョニングし、大元の親プール (`10.0.0.0/8`) を AWS RAM 経由で Spoke アカウントへ共有しています。個別ワークロード側で新規に VPC を作成する際は、静的指定の代わりに IPAM プールから動的に CIDR アロケーションを受けることが推奨されます。

#### EKS 側 (Terraform) での IPAM VPC 作成例
```hcl
data "aws_vpc_ipam_pool" "shared_parent" {
  id = var.ipam_pool_id # プラットフォーム側から同期された IPAM プール ID
}

resource "aws_vpc" "eks_vpc" {
  ipv4_ipam_pool_id   = data.aws_vpc_ipam_pool.shared_parent.id
  ipv4_netmask_length = 16 # アロケートするネットマスク長

  tags = {
    Name = "eks-vpc-from-ipam"
  }
}
```

#### ECS 側 (AWS CDK / TypeScript) での IPAM VPC 作成例
```typescript
const vpc = new ec2.Vpc(this, 'Vpc', {
  ipAddresses: ec2.IpAddresses.awsIpamAllocation({
    ipv4IpamPoolId: props.ipamPoolId,
    ipv4NetmaskLength: 16,
  }),
  maxAzs: 3,
  // ... サブネット設定など
});
```

---

## 🛠️ 個別リポジトリ側の接続実装サンプル

### A. EKS 側 (Terraform / HCL) での実装例
`learning-terraform-concepts` 等の Terraform コードベースで、TGW アタッチメントと VPC ルートを追加します。

#### 1. TGW接続専用サブネット ＆ アタッチメントの定義
VPCの既存のアプリ用サブネットとは別に、**TGW接続専用の極小サブネット (AZごとに /28 レンジ推奨)** を作成し、それを指定してアタッチします。これにより、ルートテーブルの分離と不要なIP消費の抑制が可能になります。

```hcl
# 共有されている TGW リソースを参照 (Data Source)
data "aws_ec2_transit_gateway" "shared" {
  id = var.transit_gateway_id # プラットフォーム側から同期された TGW ID
}

# 1. TGW専用サブネットの作成 (AZごとに配置)
resource "aws_subnet" "tgw" {
  count             = length(var.azs)
  vpc_id            = module.vpc.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100) # 例: 10.10.100.0/28 等
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.cluster_name}-tgw-subnet-${var.azs[count.index]}"
  }
}

# 2. TGW VPC アタッチメントの作成 (TGW専用サブネットのIDを指定)
resource "aws_ec2_transit_gateway_vpc_attachment" "eks_tgw" {
  transit_gateway_id = data.aws_ec2_transit_gateway.shared.id
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = aws_subnet.tgw[*].id

  # 自動承認を有効にしているため、アタッチメント作成後に即時疎通します
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name = "${var.cluster_name}-tgw-attachment"
  }
}
```

#### 2. サブネットルートテーブルへの TGW ルート追加（集約アウトバウンド対応）
Spoke VPC 側の NAT Gateway を完全に廃止（`single_nat_gateway = false` または `nat_gateways = 0`）した上で、プライベートサブネット用のルートテーブルに対して、インターネット宛て（`0.0.0.0/0`）のデフォルトルートの送信先を共有された TGW に設定します。

```hcl
# プライベートサブネットから TGW 宛てにデフォルトルート (0.0.0.0/0) を設定
resource "aws_route" "default_to_tgw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0" # すべてのアウトバウンド通信を TGW へ転送
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
      // ベストプラクティス: VPC構築時に 'Tgw' 等の専用サブネットグループを極小レンジで別途作成しておき、それを指定します
      subnetIds: props.vpc.selectSubnets({ subnetGroupName: 'Tgw' }).subnetIds,
      tags: [{
        key: 'Name',
        value: `${cdk.Stack.of(this).stackName}-tgw-attachment`,
      }],
    });
  }
}
```

#### 2. サブネットルートテーブルへの TGW ルート追加（集約アウトバウンド対応）
CDK VPC 構築時において、NAT Gateway を完全に排除（`natGateways: 0`）し、プライベートサブネットからインターネット宛て（`0.0.0.0/0`）のデフォルトルートを TGW へ転送するように定義します。

```typescript
const privateSubnets = props.vpc.selectSubnets({ subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS });

privateSubnets.subnets.forEach((subnet, index) => {
  new ec2.CfnRoute(this, `DefaultRouteToTgw-${index}`, {
    routeTableId: subnet.routeTable.routeTableId,
    destinationCidrBlock: '0.0.0.0/0', // すべてのアウトバウンド通信を TGW へ転送
    transitGatewayId: props.tgwId,
  });
});
```

---

## 🔍 検証および接続フロー

1.  **インフラ合成・テスト**:
    *   EKS側: `terraform plan` を実行し、`aws_ec2_transit_gateway_vpc_attachment` が正しく作成されることを検証。
    *   ECS/CDK側: `npm test` または `cdk synth` を実行し、CloudFormation テンプレートの合成エラーがないことを検証。
2.  **AWS RAM の自動承諾**:
    *   本 Landing Zone 環境では Organizations レベルでの RAM 共有（`aws_ram_sharing_with_organization`）が有効化されているため、アタッチメントの作成や共有の受け入れは**手動の承認操作なしで自動的に完了（Auto-Accept）**されます。
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
