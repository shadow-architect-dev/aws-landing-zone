#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { OrganizationsStack } from '../lib/stacks/organizations-stack';
import { IdentityStack } from '../lib/stacks/identity-stack';
import { SharedServicesStack } from '../lib/stacks/shared-services-stack';

const app = new cdk.App();

const managementEnv = {
  account: process.env.CDK_DEFAULT_ACCOUNT || '111122223333', // Placeholder / Default
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
