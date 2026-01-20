# AWS Lambda Deployment Guide
## Parquet to RDS PostgreSQL Data Pipeline

This guide walks you through deploying the parquet processing Lambda function that automatically loads data from S3 to RDS PostgreSQL.

---

## Architecture Overview

```
S3 Bucket (Parquet Upload)
    ↓ (S3 Event Trigger)
AWS Lambda Function
    ↓ (Process & Load)
RDS PostgreSQL Database
```

---

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Python 3.9+** (for local testing)
4. **RDS PostgreSQL** instance running
5. **S3 Bucket** for parquet files

---

## Step 1: Prepare Deployment Package

### Option A: Manual Package Creation (Recommended for First Time)

1. **Create a deployment directory:**
   ```bash
   mkdir lambda-deployment
   cd lambda-deployment
   ```

2. **Create virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r ../requirements-lambda.txt -t .
   ```

4. **Copy Lambda function:**
   ```bash
   cp ../lambda_function.py .
   ```

5. **Create deployment package:**
   ```bash
   # On Linux/Mac
   zip -r lambda-deployment.zip . -x "*.pyc" "__pycache__/*" "*.dist-info/*"
   
   # On Windows (PowerShell)
   Compress-Archive -Path * -DestinationPath lambda-deployment.zip
   ```

### Option B: Use Lambda Layers (Recommended for Production)

Since `pyarrow` and `pandas` are large libraries, using Lambda Layers is more efficient:

1. **Create layer package:**
   ```bash
   mkdir python
   pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t python/
   zip -r lambda-layer.zip python/
   ```

2. **Upload layer to Lambda** (see Step 3)

---

## Step 2: Create IAM Role for Lambda

1. **Go to IAM Console** → Roles → Create Role

2. **Select "AWS Lambda"** as the service

3. **Attach Policies:**
   - `AWSLambdaBasicExecutionRole` (for CloudWatch logs)
   - Create custom policy for S3 and RDS access:

   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:GetObject",
                   "s3:ListBucket"
               ],
               "Resource": [
                   "arn:aws:s3:::YOUR-BUCKET-NAME/*",
                   "arn:aws:s3:::YOUR-BUCKET-NAME"
               ]
           },
           {
               "Effect": "Allow",
               "Action": [
                   "logs:CreateLogGroup",
                   "logs:CreateLogStream",
                   "logs:PutLogEvents"
               ],
               "Resource": "arn:aws:logs:*:*:*"
           }
       ]
   }
   ```

4. **Name the role:** `lambda-parquet-processor-role`

5. **Note the Role ARN** (you'll need it in Step 3)

---

## Step 3: Create Lambda Function

### Option A: Using AWS Console

1. **Go to Lambda Console** → Functions → Create Function

2. **Configuration:**
   - **Function name:** `parquet-to-postgres-processor`
   - **Runtime:** Python 3.9, 3.10, or 3.11
   - **Architecture:** x86_64
   - **Execution role:** Select the role created in Step 2

3. **Upload Code:**
   - **Code source:** Upload a .zip file
   - Upload `lambda-deployment.zip` created in Step 1

4. **If using Lambda Layers:**
   - Go to Layers section
   - Add layer → Create new layer
   - Upload `lambda-layer.zip`
   - Add the layer to your function

5. **Configure Environment Variables:**
   ```
   DB_HOST = database-1.c3easrmf.ap-south-1.rds.amazonaws.com
   DB_NAME = postgres
   DB_PORT = 5432
   DB_USER = postgres
   DB_PASSWORD = Dashboard6287
   TABLE_NAME = audittrail_firehose
   ```

6. **Configure Basic Settings:**
   - **Timeout:** 15 minutes (900 seconds) - adjust based on file size
   - **Memory:** 3008 MB (recommended for pandas/pyarrow)
   - **Ephemeral storage:** 10240 MB (10 GB) if processing large files

### Option B: Using AWS CLI

```bash
# Create function
aws lambda create-function \
    --function-name parquet-to-postgres-processor \
    --runtime python3.11 \
    --role arn:aws:iam::YOUR-ACCOUNT-ID:role/lambda-parquet-processor-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://lambda-deployment.zip \
    --timeout 900 \
    --memory-size 3008 \
    --ephemeral-storage Size=10240 \
    --environment Variables="{DB_HOST=database-1.c3easrmf.ap-south-1.rds.amazonaws.com,DB_NAME=postgres,DB_PORT=5432,DB_USER=postgres,DB_PASSWORD=Dashboard6287,TABLE_NAME=audittrail_firehose}"

# Add layer (if using)
aws lambda update-function-configuration \
    --function-name parquet-to-postgres-processor \
    --layers arn:aws:lambda:REGION:ACCOUNT-ID:layer:parquet-layer:1
```

---

## Step 4: Configure S3 Event Trigger

1. **Go to S3 Console** → Select your bucket

2. **Properties** → Event notifications → Create event notification

3. **Configuration:**
   - **Event name:** `parquet-upload-trigger`
   - **Prefix:** (optional) e.g., `parquet-files/`
   - **Suffix:** `.parquet`
   - **Event types:** Select `PUT` (and optionally `POST`)
   - **Destination:** Lambda function
   - **Lambda function:** `parquet-to-postgres-processor`

4. **Save**

### Alternative: Using AWS CLI

```bash
aws s3api put-bucket-notification-configuration \
    --bucket YOUR-BUCKET-NAME \
    --notification-configuration '{
        "LambdaFunctionConfigurations": [{
            "Id": "parquet-upload-trigger",
            "LambdaFunctionArn": "arn:aws:lambda:REGION:ACCOUNT-ID:function:parquet-to-postgres-processor",
            "Events": ["s3:ObjectCreated:*"],
            "Filter": {
                "Key": {
                    "FilterRules": [{
                        "Name": "suffix",
                        "Value": ".parquet"
                    }]
                }
            }
        }]
    }'
```

---

## Step 5: Configure RDS Security Group

**Critical:** Ensure your RDS instance allows connections from Lambda:

1. **Go to RDS Console** → Databases → Select your database

2. **Connectivity & security** → VPC security groups

3. **Edit inbound rules:**
   - **Type:** PostgreSQL
   - **Port:** 5432
   - **Source:** 
     - Option A: Security group of your Lambda (if in same VPC)
     - Option B: `0.0.0.0/0` (for testing, not recommended for production)
     - Option C: Specific Lambda ENI IPs (if using VPC)

4. **Save**

---

## Step 6: Test the Function

### Test 1: Upload a Parquet File to S3

```bash
aws s3 cp your-file.parquet s3://YOUR-BUCKET-NAME/
```

### Test 2: Invoke Lambda Manually

```bash
aws lambda invoke \
    --function-name parquet-to-postgres-processor \
    --payload '{
        "Records": [{
            "s3": {
                "bucket": {"name": "YOUR-BUCKET-NAME"},
                "object": {"key": "your-file.parquet"}
            }
        }]
    }' \
    response.json

cat response.json
```

### Test 3: Check CloudWatch Logs

1. **Go to CloudWatch** → Log groups → `/aws/lambda/parquet-to-postgres-processor`
2. **View recent logs** for execution details

### Test 4: Verify Data in PostgreSQL

```sql
-- Connect to your RDS instance
psql -h database-1.c3easrmf.ap-south-1.rds.amazonaws.com -U postgres -d postgres

-- Check table
SELECT COUNT(*) FROM audittrail_firehose;
SELECT * FROM audittrail_firehose LIMIT 10;
```

---

## Step 7: Monitoring and Troubleshooting

### CloudWatch Metrics to Monitor:
- **Invocations:** Number of times function is triggered
- **Duration:** Execution time
- **Errors:** Failed executions
- **Throttles:** When function is rate-limited

### Common Issues:

1. **Timeout Errors:**
   - Increase Lambda timeout (max 15 minutes)
   - Consider processing files in chunks

2. **Memory Errors:**
   - Increase Lambda memory allocation
   - Process smaller batches

3. **RDS Connection Errors:**
   - Verify security group rules
   - Check RDS endpoint and credentials
   - Ensure RDS is publicly accessible (if Lambda is not in VPC)

4. **S3 Access Errors:**
   - Verify IAM role permissions
   - Check bucket policy

---

## Step 8: Cost Optimization

1. **Use Lambda Layers** to reduce package size
2. **Optimize memory** based on actual usage
3. **Set up CloudWatch alarms** for errors
4. **Consider S3 Lifecycle policies** to archive old files
5. **Use Reserved Concurrency** if needed to control costs

---

## Security Best Practices

1. **Use AWS Secrets Manager** for database credentials:
   ```python
   import boto3
   import json
   
   secrets_client = boto3.client('secretsmanager')
   secret = secrets_client.get_secret_value(SecretId='rds-postgres-credentials')
   credentials = json.loads(secret['SecretString'])
   ```

2. **Enable VPC** for Lambda if RDS is in private subnet
3. **Use IAM roles** instead of hardcoded credentials
4. **Enable encryption** for S3 and RDS
5. **Regularly rotate** database passwords

---

## Next Steps

- Set up CloudWatch alarms for monitoring
- Configure dead-letter queue for failed executions
- Implement retry logic for transient failures
- Add data validation before loading
- Set up automated testing pipeline

---

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review Lambda function metrics
3. Verify IAM permissions
4. Test database connectivity separately

