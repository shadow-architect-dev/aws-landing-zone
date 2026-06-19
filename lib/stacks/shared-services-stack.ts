import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as iam from 'aws-cdk-lib/aws-iam';

interface SharedServicesStackProps extends cdk.StackProps {
  githubRepo?: string;
}

export class SharedServicesStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: SharedServicesStackProps) {
    super(scope, id, props);

    const githubRepo = props?.githubRepo || 'shadow-architect-dev/learning-ts-concepts';

    // 1. GitHub Actions 用の OIDC プロバイダーを作成
    // 注意: 同一アカウント内にすでに存在する場合は既存のプロバイダーを参照するように設定する必要がありますが、
    // 新規アカウントセットアップ用にプロバイダーを定義します。
    const oidcProvider = new iam.OpenIdConnectProvider(this, 'GitHubOidcProvider', {
      url: 'https://token.actions.githubusercontent.com',
      clientIds: ['sts.amazonaws.com'],
    });

    // 2. GitHub Actions が一時認証情報を取得するための IAM ロールを作成
    const deployRole = new iam.Role(this, 'GitHubActionsWorkflowDeployRole', {
      roleName: 'GitHubActionsWorkflowDeployRole',
      assumedBy: new iam.FederatedPrincipal(
        oidcProvider.openIdConnectProviderArn,
        {
          StringEquals: {
            'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
          },
          StringLike: {
            'token.actions.githubusercontent.com:sub': `repo:${githubRepo}:*`,
          },
        },
        'sts:AssumeRoleWithWebIdentity'
      ),
      description: `Deployment role assumed by GitHub Actions for repository: ${githubRepo}`,
      maxSessionDuration: cdk.Duration.hours(2),
    });

    // 3. デプロイ権限の付与 (ここではデモ・セットアップ用に管理権限を付与)
    deployRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AdministratorAccess'));

    // Outputs
    new cdk.CfnOutput(this, 'GitHubDeployRoleArn', {
      value: deployRole.roleArn,
      description: 'IAM Role ARN for GitHub Actions deployment',
    });
  }
}
