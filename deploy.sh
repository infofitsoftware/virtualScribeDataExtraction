#!/bin/bash
# Deployment script for Lambda function
# Usage: ./deploy.sh [function-name] [bucket-name]

set -e

FUNCTION_NAME=${1:-"parquet-to-postgres-processor"}
BUCKET_NAME=${2:-""}

echo "=========================================="
echo "Lambda Deployment Script"
echo "=========================================="
echo "Function Name: $FUNCTION_NAME"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Create deployment directory
echo -e "${YELLOW}Step 1: Preparing deployment package...${NC}"
rm -rf lambda-deployment
mkdir -p lambda-deployment
cd lambda-deployment

# Step 2: Install dependencies
echo -e "${YELLOW}Step 2: Installing dependencies...${NC}"
pip install -r ../requirements-lambda.txt -t . --quiet

# Step 3: Copy Lambda function
echo -e "${YELLOW}Step 3: Copying Lambda function...${NC}"
cp ../lambda_function.py .

# Step 4: Create deployment package
echo -e "${YELLOW}Step 4: Creating deployment package...${NC}"
zip -r ../lambda-deployment.zip . -q -x "*.pyc" "__pycache__/*" "*.dist-info/*" "*.egg-info/*"

cd ..
echo -e "${GREEN}✓ Deployment package created: lambda-deployment.zip${NC}"

# Step 5: Check if function exists
echo -e "${YELLOW}Step 5: Checking if function exists...${NC}"
if aws lambda get-function --function-name $FUNCTION_NAME &>/dev/null; then
    echo -e "${YELLOW}Function exists. Updating...${NC}"
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda-deployment.zip
    
    echo -e "${GREEN}✓ Function code updated${NC}"
else
    echo -e "${YELLOW}Function does not exist. Please create it first using AWS Console or CLI.${NC}"
    echo -e "${YELLOW}See DEPLOYMENT_GUIDE.md for instructions.${NC}"
fi

# Step 6: Update environment variables (if needed)
echo -e "${YELLOW}Step 6: Verifying environment variables...${NC}"
echo -e "${YELLOW}Make sure to set these in Lambda console:${NC}"
echo "  DB_HOST=database-1.c3easrmf.ap-south-1.rds.amazonaws.com"
echo "  DB_NAME=postgres"
echo "  DB_PORT=5432"
echo "  DB_USER=postgres"
echo "  DB_PASSWORD=Dashboard6287"
echo "  TABLE_NAME=audittrail_firehose"

# Step 7: Configure S3 trigger (if bucket name provided)
if [ ! -z "$BUCKET_NAME" ]; then
    echo -e "${YELLOW}Step 7: Configuring S3 trigger for bucket: $BUCKET_NAME${NC}"
    
    FUNCTION_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)
    
    # Add permission for S3 to invoke Lambda
    aws lambda add-permission \
        --function-name $FUNCTION_NAME \
        --principal s3.amazonaws.com \
        --statement-id s3-trigger-permission \
        --action "lambda:InvokeFunction" \
        --source-arn "arn:aws:s3:::$BUCKET_NAME" \
        --source-account $(aws sts get-caller-identity --query Account --output text) 2>/dev/null || echo "Permission may already exist"
    
    echo -e "${GREEN}✓ S3 trigger permission added${NC}"
    echo -e "${YELLOW}Note: You still need to configure the S3 event notification in the S3 console.${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Verify environment variables in Lambda console"
echo "2. Configure S3 event notification"
echo "3. Test by uploading a parquet file to S3"
echo "4. Check CloudWatch logs for execution details"

