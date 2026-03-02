#!/bin/bash

# Script to create a placeholder Lambda deployment package
# This is used for the example Lambda function in example-application.tf

set -e

echo "Creating Lambda deployment package..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Create a simple Lambda handler
cat > index.py << 'EOF'
import json
import boto3
import os

def handler(event, context):
    """
    Example Lambda function that retrieves secrets from AWS Secrets Manager
    """

    # Get secret ARNs from environment variables
    db_secret_arn = os.environ.get('DB_SECRET_ARN')
    api_secret_arn = os.environ.get('API_SECRET_ARN')
    app_secret_arn = os.environ.get('APP_SECRET_ARN')
    environment = os.environ.get('ENVIRONMENT', 'unknown')

    # Initialize Secrets Manager client
    sm_client = boto3.client('secretsmanager')

    try:
        # Retrieve database secret
        db_secret = sm_client.get_secret_value(SecretId=db_secret_arn)
        db_data = json.loads(db_secret['SecretString'])

        # Retrieve API secret
        api_secret = sm_client.get_secret_value(SecretId=api_secret_arn)
        api_data = json.loads(api_secret['SecretString'])

        # Retrieve app config secret
        app_secret = sm_client.get_secret_value(SecretId=app_secret_arn)
        app_data = json.loads(app_secret['SecretString'])

        # NOTE: In production, never log or return actual secret values!
        # This is for demonstration purposes only

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Secrets retrieved successfully',
                'environment': environment,
                'secrets_accessed': [
                    'db_password',
                    'api_key',
                    'app_config'
                ],
                # Return metadata only, not actual secrets
                'db_host': db_data.get('host'),
                'db_username': db_data.get('username'),
                'api_service': api_data.get('service'),
                'note': 'Actual secret values are not returned for security'
            })
        }

    except Exception as e:
        print(f"Error retrieving secrets: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Failed to retrieve secrets',
                'message': str(e)
            })
        }
EOF

# Create deployment package
zip -q placeholder.zip index.py

# Move to scripts directory
mv placeholder.zip ../placeholder.zip

# Cleanup
cd ..
rm -rf "$TEMP_DIR"

echo "✓ Lambda deployment package created: placeholder.zip"
echo ""
echo "To deploy:"
echo "  cd iaac_secret_management"
echo "  terraform apply"
