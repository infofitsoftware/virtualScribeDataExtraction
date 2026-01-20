# Quick Start Checklist

## Pre-Deployment Checklist

- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] RDS PostgreSQL instance is running and accessible
- [ ] S3 bucket created for parquet files
- [ ] Python 3.9+ installed locally (for packaging)

## Deployment Steps (Quick Reference)

### 1. Create IAM Role (5 minutes)
```
IAM Console → Roles → Create Role
- Service: AWS Lambda
- Attach: AWSLambdaBasicExecutionRole
- Add custom policy for S3 and RDS access
- Name: lambda-parquet-processor-role
```

### 2. Package Lambda Function (2 minutes)
```bash
# Linux/Mac
chmod +x deploy.sh
./deploy.sh

# Windows PowerShell
.\deploy.ps1
```

### 3. Create Lambda Function (5 minutes)
```
Lambda Console → Create Function
- Name: parquet-to-postgres-processor
- Runtime: Python 3.11
- Role: lambda-parquet-processor-role
- Upload: lambda-deployment.zip
- Timeout: 900 seconds (15 min)
- Memory: 3008 MB
- Ephemeral Storage: 10240 MB
```

### 4. Set Environment Variables
```
DB_HOST = database-1.c3easrmf.ap-south-1.rds.amazonaws.com
DB_NAME = postgres
DB_PORT = 5432
DB_USER = postgres
DB_PASSWORD = Dashboard6287
TABLE_NAME = audittrail_firehose
```

### 5. Configure S3 Trigger (3 minutes)
```
S3 Console → Your Bucket → Properties → Event notifications
- Event name: parquet-upload-trigger
- Suffix: .parquet
- Event: PUT
- Destination: Lambda function → parquet-to-postgres-processor
```

### 6. Configure RDS Security Group (5 minutes)
```
RDS Console → Your Database → Connectivity & security
- Edit inbound rules
- Type: PostgreSQL, Port: 5432
- Source: 0.0.0.0/0 (or Lambda security group if in VPC)
```

### 7. Test (2 minutes)
```bash
# Upload test file
aws s3 cp test.parquet s3://YOUR-BUCKET-NAME/

# Check CloudWatch logs
aws logs tail /aws/lambda/parquet-to-postgres-processor --follow
```

## Total Time: ~25 minutes

## Troubleshooting Quick Fixes

| Issue | Solution |
|-------|----------|
| Timeout | Increase Lambda timeout to 900 seconds |
| Memory Error | Increase Lambda memory to 3008 MB |
| RDS Connection Failed | Check security group allows Lambda IPs |
| S3 Access Denied | Verify IAM role has S3 GetObject permission |
| Package Too Large | Use Lambda Layers for pyarrow/pandas |

## Important URLs

- **Lambda Console:** https://console.aws.amazon.com/lambda
- **S3 Console:** https://console.aws.amazon.com/s3
- **RDS Console:** https://console.aws.amazon.com/rds
- **CloudWatch Logs:** https://console.aws.amazon.com/cloudwatch

