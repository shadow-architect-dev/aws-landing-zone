#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { OrganizationsStack } from '../lib/stacks/organizations-stack';
import { IdentityStack } from '../lib/stacks/identity-stack';
import { SharedServicesStack } from '../lib/stacks/shared-services-stack';
import { LogArchiveStack } from '../lib/stacks/log-archive-stack';
import { SecurityAuditStack } from '../lib/stacks/security-audit-stack';
import * as fs from 'fs';
import * as path from 'path';

const app = new cdk.App();

// 設定ファイルの読み込み
const configPath = path.join(__dirname, '../config/landing-zone-config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const managementEnv = {
  account: process.env.CDK_DEFAULT_ACCOUNT || config.organization.management || '111122223333',
  region: 'ap-northeast-1',
};

const logArchiveEnv = {
  account: config.accounts.logArchive || '222222222222',
  region: 'ap-northeast-1',
};

const auditEnv = {
  account: config.accounts.audit || '333333333333',
  region: 'ap-northeast-1',
};

// 1. AWS Organizations & SCP Management Stack
new OrganizationsStack(app, 'LandingZoneOrganizationsStack', {
  env: managementEnv,
  description: 'AWS Organizations OU and SCP policies baseline configuration.',
});

// 2. AWS IAM Identity Center Configuration Stack
new IdentityStack(app, 'LandingZoneIdentityStack', {
  env: managementEnv,
  description: 'AWS IAM Identity Center permission sets and group mappings.',
});

// 3. Shared Services & Cross-Account Role Stack
new SharedServicesStack(app, 'LandingZoneSharedServicesStack', {
  env: managementEnv,
  description: 'Shared services baseline configurations, including CI/CD OIDC roles.',
});

// 4. AWS Log Archive Stack (Log Archive アカウントにデプロイ)
new LogArchiveStack(app, 'LandingZoneLogArchiveStack', {
  env: logArchiveEnv,
  description: 'AWS Log Archive infrastructure including S3 storage and Kinesis Firehose.',
});

// 5. AWS Security Audit Stack (Audit / Security アカウントにデプロイ)
new SecurityAuditStack(app, 'LandingZoneSecurityAuditStack', {
  env: auditEnv,
  description: 'AWS Config Aggregator and GuardDuty central security configurations.',
});
