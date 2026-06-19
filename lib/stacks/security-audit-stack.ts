import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as config from 'aws-cdk-lib/aws-config';
import * as guardduty from 'aws-cdk-lib/aws-guardduty';
import * as securityhub from 'aws-cdk-lib/aws-securityhub';
import * as cr from 'aws-cdk-lib/custom-resources';

export class SecurityAuditStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // -------------------------------------------------------------------------
    // 1. AWS Config 組織アグリゲーター (Configuration Aggregator) の構築
    // -------------------------------------------------------------------------

    // Config Aggregator が Organizations の情報を読み取るための IAM ロール
    const aggregatorRole = new iam.Role(this, 'ConfigAggregatorRole', {
      assumedBy: new iam.ServicePrincipal('config.amazonaws.com'),
      description: 'IAM Role for AWS Config Aggregator to retrieve Organization metadata',
    });

    // 組織全体の情報を読み取るためのポリシーをアタッチ
    aggregatorRole.addManagedPolicy(
      iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSConfigRoleForOrganizations')
    );

    // Config 組織アグリゲーターの定義
    new config.CfnConfigurationAggregator(this, 'OrganizationConfigAggregator', {
      configurationAggregatorName: 'OrganizationConfigAggregator',
      organizationAggregationSource: {
        roleArn: aggregatorRole.roleArn,
        allAwsRegions: true,
      },
    });

    // -------------------------------------------------------------------------
    // 2. Amazon GuardDuty の検出器 (Detector) の有効化と組織自動有効化
    // -------------------------------------------------------------------------

    const auditDetector = new guardduty.CfnDetector(this, 'AuditAccountGuardDutyDetector', {
      enable: true,
      findingPublishingFrequency: 'FIFTEEN_MINUTES',
    });

    // 組織内の新規アカウント追加時に自動で GuardDuty を有効化する設定 (AWS Custom Resource)
    // ※ 委任管理者（Delegated Administrator）として登録された後に有効に動作します。
    new cr.AwsCustomResource(this, 'GuardDutyOrganizationConfig', {
      onUpdate: {
        service: 'GuardDuty',
        action: 'updateOrganizationConfiguration',
        parameters: {
          DetectorId: auditDetector.ref,
          AutoEnable: true,
        },
        physicalResourceId: cr.PhysicalResourceId.of('GuardDutyOrgConfig'),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: [
            'guardduty:UpdateOrganizationConfiguration',
          ],
          resources: ['*'],
        }),
      ]),
    });

    // -------------------------------------------------------------------------
    // 3. AWS Security Hub の有効化と組織自動有効化
    // -------------------------------------------------------------------------

    // Security Hub 検出器の作成 (有効化)
    new securityhub.CfnHub(this, 'AuditAccountSecurityHub', {
      enableDefaultStandards: true, // AWS 基礎セキュリティのベストプラクティス等の標準規格を有効化
    });

    // 組織内の新規アカウント追加時に自動で Security Hub を有効化する設定 (AWS Custom Resource)
    // ※ 委任管理者（Delegated Administrator）として登録された後に有効に動作します。
    new cr.AwsCustomResource(this, 'SecurityHubOrganizationConfig', {
      onUpdate: {
        service: 'SecurityHub',
        action: 'updateOrganizationConfiguration',
        parameters: {
          AutoEnable: true,
        },
        physicalResourceId: cr.PhysicalResourceId.of('SecurityHubOrgConfig'),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: [
            'securityhub:UpdateOrganizationConfiguration',
          ],
          resources: ['*'],
        }),
      ]),
    });
  }
}
