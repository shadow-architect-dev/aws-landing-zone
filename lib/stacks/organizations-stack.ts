import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as organizations from 'aws-cdk-lib/aws-organizations';
import * as cr from 'aws-cdk-lib/custom-resources';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as cloudtrail from 'aws-cdk-lib/aws-cloudtrail';
import * as fs from 'fs';
import * as path from 'path';

export class OrganizationsStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. 設定ファイルの読み込み
    const configPath = path.join(__dirname, '../../config/landing-zone-config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const rootId = config.organization.rootId;
    const prodAccountId = config.accounts.prod;
    const auditAccountId = config.accounts.audit;
    const logArchiveAccountId = config.accounts.logArchive;

    // 2. OU (Organizational Unit) の作成
    // Core OU
    const coreOu = new organizations.CfnOrganizationalUnit(this, 'CoreOU', {
      name: 'Core',
      parentId: rootId,
    });

    // Workloads OU
    const workloadsOu = new organizations.CfnOrganizationalUnit(this, 'WorkloadsOU', {
      name: 'Workloads',
      parentId: rootId,
    });

    // 3. SCP (Service Control Policy) 定義の読み込み
    const policiesDir = path.join(__dirname, '../../policies/scp');

    const restrictRegionsContent = JSON.parse(fs.readFileSync(
      path.join(policiesDir, 'restrict-regions.json'),
      'utf8'
    ));
    const protectSecurityServicesContent = JSON.parse(fs.readFileSync(
      path.join(policiesDir, 'protect-security-services.json'),
      'utf8'
    ));
    const preventProdDeletionContent = JSON.parse(fs.readFileSync(
      path.join(policiesDir, 'prevent-prod-deletion.json'),
      'utf8'
    ));

    // 4. SCP の作成および OU / アカウントへのアタッチ
    // リージョン制限 SCP (Core OU および Workloads OU にアタッチ)
    new organizations.CfnPolicy(this, 'RestrictRegionsPolicy', {
      name: 'RestrictRegionsToTokyo',
      description: 'Restrict resource creation to ap-northeast-1 only.',
      type: 'SERVICE_CONTROL_POLICY',
      content: restrictRegionsContent,
      targetIds: [coreOu.ref, workloadsOu.ref],
    });

    // セキュリティサービス保護 SCP (Core OU および Workloads OU にアタッチ)
    new organizations.CfnPolicy(this, 'ProtectSecurityServicesPolicy', {
      name: 'ProtectSecurityServices',
      description: 'Prevent disabling or deleting security services (CloudTrail, GuardDuty, SecurityHub, Config).',
      type: 'SERVICE_CONTROL_POLICY',
      content: protectSecurityServicesContent,
      targetIds: [coreOu.ref, workloadsOu.ref],
    });

    // 本番データ削除防止 SCP (本番環境のアカウントにアタッチ)
    new organizations.CfnPolicy(this, 'PreventProdDeletionPolicy', {
      name: 'PreventProdDeletion',
      description: 'Prevent deletion of critical data resources in production environment.',
      type: 'SERVICE_CONTROL_POLICY',
      content: preventProdDeletionContent,
      targetIds: [prodAccountId],
    });

    // 5. タグポリシー (Tag Policy) の定義読み込みと作成・アタッチ
    const tagPoliciesDir = path.join(__dirname, '../../policies/tag-policies');
    const enforceMandatoryTagsContent = JSON.parse(fs.readFileSync(
      path.join(tagPoliciesDir, 'enforce-mandatory-tags.json'),
      'utf8'
    ));

    // タグポリシー作成 (Workloads OU にアタッチ)
    new organizations.CfnPolicy(this, 'EnforceMandatoryTagsPolicy', {
      name: 'EnforceMandatoryTags',
      description: 'Enforce Environment and Project tags with standard values on workload resources.',
      type: 'TAG_POLICY',
      content: enforceMandatoryTagsContent,
      targetIds: [workloadsOu.ref],
    });

    // 6. GuardDuty 組織委任管理者 (Delegated Administrator) の指定
    new cr.AwsCustomResource(this, 'EnableGuardDutyDelegatedAdmin', {
      onUpdate: {
        service: 'GuardDuty',
        action: 'enableOrganizationAdminAccount',
        parameters: {
          AdminAccountId: auditAccountId,
        },
        physicalResourceId: cr.PhysicalResourceId.of('GuardDutyDelegatedAdmin'),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: [
            'guardduty:EnableOrganizationAdminAccount',
            'organizations:EnableAWSServiceAccess',
            'organizations:RegisterDelegatedAdministrator',
          ],
          resources: ['*'],
        }),
      ]),
    });

    // 7. 組織の証跡 (Organization Trail) の構築
    // Log Archive アカウントの S3 バケットの参照
    const logBucketArn = `arn:aws:s3:::aws-landing-zone-log-archive-${logArchiveAccountId}-ap-northeast-1`;
    const logBucket = s3.Bucket.fromBucketArn(this, 'LogArchiveBucketRef', logBucketArn);

    // 組織全体の証跡 (Organization Trail) を作成し、Log Archive バケットに格納
    new cloudtrail.Trail(this, 'OrganizationTrail', {
      bucket: logBucket,
      isOrganizationTrail: true,
      sendToCloudWatchLogs: false, // S3バケットへ直接転送
      enableFileValidation: true, // ログの改ざん検知機能を有効化
      includeGlobalServiceEvents: true,
      managementEvents: cloudtrail.ReadWriteType.ALL,
    });

    // Outputs
    new cdk.CfnOutput(this, 'CoreOuId', {
      value: coreOu.ref,
      description: 'Core Organizational Unit ID',
    });

    new cdk.CfnOutput(this, 'WorkloadsOuId', {
      value: workloadsOu.ref,
      description: 'Workloads Organizational Unit ID',
    });
  }
}
