import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as kms from 'aws-cdk-lib/aws-kms';
import * as kinesisfirehose from 'aws-cdk-lib/aws-kinesisfirehose';
import * as fs from 'fs';
import * as path from 'path';

export class LogArchiveStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. 設定ファイルの読み込み
    const configPath = path.join(__dirname, '../../config/landing-zone-config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

    // 2. ログ暗号化用のカスタマー管理型 KMS キーの構築
    const cloudtrailKey = new kms.Key(this, 'CloudTrailEncryptionKey', {
      alias: 'alias/cloudtrail-log-archive-key',
      description: 'KMS Key for encrypting AWS CloudTrail logs in S3',
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    // CloudTrail サービスによる鍵の使用を許可するポリシーを追加
    cloudtrailKey.addToResourcePolicy(new iam.PolicyStatement({
      sid: 'AllowCloudTrailEncrypt',
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('cloudtrail.amazonaws.com')],
      actions: [
        'kms:GenerateDataKey*',
        'kms:DescribeKey',
      ],
      resources: ['*'],
      conditions: {
        StringLike: {
          'kms:EncryptionContext:aws:cloudtrail:arn': [
            `arn:aws:cloudtrail:*:${config.organization.management || '111122223333'}:trail/*`,
          ],
        },
      },
    }));

    // 3. ログ保管用 S3 バケットの構築 (KMS暗号化を適用)
    const logBucket = new s3.Bucket(this, 'LogArchiveBucket', {
      bucketName: `aws-landing-zone-log-archive-${this.account}-${this.region}`,
      encryption: s3.BucketEncryption.KMS,
      encryptionKey: cloudtrailKey, // SSE-KMS
      versioned: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN, // 削除保護 (Keep the bucket even if stack is deleted)
      enforceSSL: true, // SSLのみの接続を強制
    });

    // S3 バケットポリシーの追加 (CloudTrail からのクロスアカウントログ書き込みを許可)
    // 1. ACLの確認許可
    logBucket.addToResourcePolicy(new iam.PolicyStatement({
      sid: 'AWSCloudTrailAclCheck',
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('cloudtrail.amazonaws.com')],
      actions: ['s3:GetBucketAcl'],
      resources: [logBucket.bucketArn],
    }));

    // 2. ログファイルの書き込み許可 (バケット所有者のフルコントロール権限指定を強制)
    logBucket.addToResourcePolicy(new iam.PolicyStatement({
      sid: 'AWSCloudTrailWrite',
      effect: iam.Effect.ALLOW,
      principals: [new iam.ServicePrincipal('cloudtrail.amazonaws.com')],
      actions: ['s3:PutObject'],
      resources: [
        logBucket.arnForObjects('AWSLogs/*'),
        logBucket.arnForObjects('workloads/AWSLogs/*'),
      ],
      conditions: {
        StringEquals: {
          's3:x-amz-acl': 'bucket-owner-full-control',
        },
      },
    }));

    // 4. Kinesis Data Firehose が S3 に書き込むための IAM ロール
    const firehoseRole = new iam.Role(this, 'FirehoseToS3Role', {
      assumedBy: new iam.ServicePrincipal('firehose.amazonaws.com'),
      description: 'IAM Role for Kinesis Data Firehose to write logs to S3',
    });

    logBucket.grantReadWrite(firehoseRole);

    // Kinesis Firehose にも KMS キーの使用許可を付与
    cloudtrailKey.grantEncryptDecrypt(firehoseRole);

    // 5. Kinesis Data Firehose (配信ストリーム) の構築
    const deliveryStream = new kinesisfirehose.CfnDeliveryStream(this, 'LogArchiveDeliveryStream', {
      deliveryStreamName: 'LogArchiveDeliveryStream',
      deliveryStreamType: 'DirectPut',
      extendedS3DestinationConfiguration: {
        bucketArn: logBucket.bucketArn,
        roleArn: firehoseRole.roleArn,
        bufferingHints: {
          intervalInSeconds: 300,
          sizeInMBs: 5,
        },
        compressionFormat: 'GZIP',
        prefix: 'workloads/',
        errorOutputPrefix: 'errors/',
      },
    });

    // 6. クロスアカウント配信用の IAM ロール (Workloads アカウントの CloudWatch Logs 用)
    const crossAccountDeliveryRole = new iam.Role(this, 'CrossAccountLogsDeliveryRole', {
      roleName: 'CrossAccountLogsDeliveryRole',
      assumedBy: new iam.ServicePrincipal('logs.amazonaws.com', {
        conditions: {
          StringEquals: {
            'aws:SourceAccount': [
              config.accounts.dev,
              config.accounts.stg,
              config.accounts.prod,
            ],
          },
        },
      }),
      description: 'IAM Role for cross-account CloudWatch Logs to put records into Kinesis Firehose',
    });

    // Firehose への書き込み権限をロールに付与
    crossAccountDeliveryRole.addToPolicy(new iam.PolicyStatement({
      actions: [
        'firehose:PutRecord',
        'firehose:PutRecordBatch',
      ],
      resources: [
        deliveryStream.attrArn,
      ],
    }));

    // Outputs
    new cdk.CfnOutput(this, 'LogArchiveBucketArn', {
      value: logBucket.bucketArn,
      description: 'ARN of the Log Archive S3 Bucket',
    });

    new cdk.CfnOutput(this, 'LogArchiveFirehoseArn', {
      value: deliveryStream.attrArn,
      description: 'ARN of the Log Archive Kinesis Firehose Stream',
      exportName: 'LogArchiveFirehoseArn',
    });

    new cdk.CfnOutput(this, 'LogArchiveDeliveryRoleArn', {
      value: crossAccountDeliveryRole.roleArn,
      description: 'ARN of the Cross-Account Logs Delivery IAM Role',
      exportName: 'LogArchiveDeliveryRoleArn',
    });

    new cdk.CfnOutput(this, 'CloudTrailKmsKeyArn', {
      value: cloudtrailKey.keyArn,
      description: 'ARN of the CloudTrail KMS Key',
      exportName: 'CloudTrailKmsKeyArn',
    });
  }
}
