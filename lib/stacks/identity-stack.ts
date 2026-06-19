import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
// import * as sso from 'aws-cdk-lib/aws-sso';

export class IdentityStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // AWS IAM Identity Center (SSO) 構成
    // 注意: Identity Center インスタンスは各組織で1つのみ作成可能で、通常は管理アカウントで手動で有効化されます。
    // 本スタックでは、有効化されたインスタンスARNを参照して Permission Set (権限セット) やグループ割り当てを行います。

    /*
    // 例: 実際のSSOインスタンスARNを設定します
    const ssoInstanceArn = 'arn:aws:sso:::instance/ssoins-xxxxxxxxxxxxxxxx';

    // 1. 管理者権限セット
    const adminPermissionSet = new sso.CfnPermissionSet(this, 'AdminPermissionSet', {
      instanceArn: ssoInstanceArn,
      name: 'AdministratorAccessSet',
      description: 'AdministratorAccess Permission Set managed by Landing Zone CDK.',
      managedPolicies: [
        'arn:aws:iam::aws:policy/AdministratorAccess'
      ],
      sessionDuration: 'PT4H', // 4時間有効
    });

    // 2. 閲覧専用権限セット
    const readOnlyPermissionSet = new sso.CfnPermissionSet(this, 'ReadOnlyPermissionSet', {
      instanceArn: ssoInstanceArn,
      name: 'ReadOnlyAccessSet',
      description: 'ReadOnlyAccess Permission Set managed by Landing Zone CDK.',
      managedPolicies: [
        'arn:aws:iam::aws:policy/ReadOnlyAccess'
      ],
      sessionDuration: 'PT8H', // 8時間有効
    });
    */
  }
}
