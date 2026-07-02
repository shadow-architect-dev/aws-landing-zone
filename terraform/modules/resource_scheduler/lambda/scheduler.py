import os
import boto3
import logging

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')

SCHEDULE_TAG_KEY = 'Schedule'
SCHEDULE_TAG_VALUE = os.environ.get('SCHEDULE_TAG_VALUE', 'office-hours')

def lambda_handler(event, context):
    action = event.get('action', '').lower()
    if action not in ['start', 'stop']:
        logger.error(f"Invalid action '{action}'. Action must be 'start' or 'stop'.")
        return {"status": "error", "message": f"Invalid action '{action}'"}

    logger.info(f"Starting auto-scheduler execution. Action: {action.upper()}, Target Tag: {SCHEDULE_TAG_KEY}={SCHEDULE_TAG_VALUE}")

    # 1. EC2 Scheduler
    handle_ec2(action)

    # 2. RDS Scheduler
    handle_rds(action)

    logger.info("Auto-scheduler execution completed.")
    return {"status": "success", "action": action}

def handle_ec2(action):
    # Filter EC2 instances by Schedule tag and current state
    filters = [
        {'Name': f'tag:{SCHEDULE_TAG_KEY}', 'Values': [SCHEDULE_TAG_VALUE]}
    ]
    
    try:
        response = ec2_client.describe_instances(Filters=filters)
        instance_ids = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_ids.append(instance['InstanceId'])
        
        if not instance_ids:
            logger.info("No matching EC2 instances found for auto-scheduling.")
            return

        if action == 'stop':
            logger.info(f"Stopping EC2 instances: {instance_ids}")
            ec2_client.stop_instances(InstanceIds=instance_ids)
        elif action == 'start':
            logger.info(f"Starting EC2 instances: {instance_ids}")
            ec2_client.start_instances(InstanceIds=instance_ids)

    except Exception as e:
        logger.error(f"Error executing EC2 scheduler: {str(e)}")

def handle_rds(action):
    try:
        response = rds_client.describe_db_instances()
        target_db_identifiers = []

        for db_instance in response['DBInstances']:
            db_id = db_instance['DBInstanceIdentifier']
            # RDS tags are fetched via separate API or list in instance structure
            arn = db_instance['DBInstanceArn']
            tags_response = rds_client.list_tags_for_resource(ResourceName=arn)
            
            for tag in tags_response['TagList']:
                if tag['Key'] == SCHEDULE_TAG_KEY and tag['Value'] == SCHEDULE_TAG_VALUE:
                    target_db_identifiers.append(db_id)
                    break
        
        if not target_db_identifiers:
            logger.info("No matching RDS database instances found for auto-scheduling.")
            return

        for db_id in target_db_identifiers:
            if action == 'stop':
                logger.info(f"Stopping RDS instance: {db_id}")
                # RDS stop fails if not in 'available' state
                try:
                    rds_client.stop_db_instance(DBInstanceIdentifier=db_id)
                except Exception as ex:
                    logger.warning(f"Failed to stop RDS {db_id}. Resource state might be invalid: {str(ex)}")
            elif action == 'start':
                logger.info(f"Starting RDS instance: {db_id}")
                # RDS start fails if not in 'stopped' state
                try:
                    rds_client.start_db_instance(DBInstanceIdentifier=db_id)
                except Exception as ex:
                    logger.warning(f"Failed to start RDS {db_id}. Resource state might be invalid: {str(ex)}")

    except Exception as e:
        logger.error(f"Error executing RDS scheduler: {str(e)}")
