# Step-by-Step Deployment Guide
## AWS Lambda: S3 Parquet → RDS PostgreSQL Pipeline

---

## 🎯 Goal
Automatically process parquet files uploaded to S3 and load them into RDS PostgreSQL using AWS Lambda.

---

## 📋 Prerequisites Checklist

- [ ] AWS Account with admin/appropriate permissions
- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS CLI configured (`aws configure`)
- [ ] RDS PostgreSQL instance running
- [ ] S3 bucket created
- [ ] Python 3.9+ installed locally

---

## Step 1: Create IAM Role for Lambda (5 minutes)

### 1.1 Go to IAM Console
- Navigate to: https://console.aws.amazon.com/iam
- Click **Roles** → **Create role**

### 1.2 Select Trusted Entity
- Select **AWS service**
- Choose **Lambda**
- Click **Next**

### 1.3 Attach Policies
- Search and attach: **AWSLambdaBasicExecutionRole**
- Click **Create policy** (for custom permissions)

### 1.4 Create Custom Policy
Click **Create policy** → **JSON** tab, paste:

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

**Replace `YOUR-BUCKET-NAME` with your actual bucket name**

- Name: `lambda-parquet-s3-rds-policy`
- Click **Create policy**
- Go back to role creation
- Refresh and attach the new policy

### 1.5 Name the Role
- Role name: `lambda-parquet-processor-role`
- Click **Create role**
- **Note the Role ARN** (you'll need it later)

---

## Step 2: Prepare Lambda Deployment Package (5 minutes)

### 2.1 Create Deployment Directory
```bash
# Windows PowerShell
mkdir lambda-deployment
cd lambda-deployment

# Linux/Mac
mkdir lambda-deployment && cd lambda-deployment
```

### 2.2 Install Dependencies
```bash
# Create virtual environment (optional but recommended)
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# Install dependencies
pip install -r ../requirements-lambda.txt -t .
```

### 2.3 Copy Lambda Function
```bash
# Windows
copy ..\lambda_function.py .

# Linux/Mac
cp ../lambda_function.py .
```

### 2.4 Create ZIP Package
```bash
# Windows PowerShell
cd ..
Compress-Archive -Path lambda-deployment\* -DestinationPath lambda-deployment.zip -Force

# Linux/Mac
cd ..
zip -r lambda-deployment.zip lambda-deployment/ -x "*.pyc" "__pycache__/*" "*.dist-info/*"
```

**OR use the provided deployment script:**
```bash
# Windows
.\deploy.ps1

# Linux/Mac
chmod +x deploy.sh
./deploy.sh
```

---

## Step 3: Create Lambda Function (10 minutes)

### 3.1 Go to Lambda Console
- Navigate to: https://console.aws.amazon.com/lambda
- Click **Create function**

### 3.2 Basic Configuration
- **Function name:** `parquet-to-postgres-processor`
- **Runtime:** Python 3.11 (or 3.10, 3.9)
- **Architecture:** x86_64
- **Execution role:** Use existing role
- **Role:** Select `lambda-parquet-processor-role` (created in Step 1)
- Click **Create function**

### 3.3 Upload Code
- Scroll to **Code source** section
- Click **Upload from** → **.zip file**
- Upload `lambda-deployment.zip`
- Wait for upload to complete

### 3.4 Configure Environment Variables
Scroll to **Configuration** → **Environment variables** → **Edit**:

| Key | Value |
|-----|-------|
| `DB_HOST` | `database-1.c3easrmf.ap-south-1.rds.amazonaws.com` |
| `DB_NAME` | `postgres` |
| `DB_PORT` | `5432` |
| `DB_USER` | `postgres` |
| `DB_PASSWORD` | `Dashboard6287` |
| `TABLE_NAME` | `audittrail_firehose` |

Click **Save**

### 3.5 Configure Basic Settings
- Click **Configuration** → **General configuration** → **Edit**
- **Timeout:** `15 min 0 sec` (900 seconds)
- **Memory:** `3008 MB`
- **Ephemeral storage:** `10240 MB` (10 GB)
- Click **Save**

---

## Step 4: Configure S3 Event Trigger (5 minutes)

### 4.1 Go to S3 Console
- Navigate to: https://console.aws.amazon.com/s3
- Click on your bucket name

### 4.2 Create Event Notification
- Click **Properties** tab
- Scroll to **Event notifications**
- Click **Create event notification**

### 4.3 Configure Event
- **Event name:** `parquet-upload-trigger`
- **Prefix:** (optional, e.g., `parquet-files/`)
- **Suffix:** `.parquet`
- **Event types:** 
  - ✅ `PUT` (when file is uploaded)
  - ✅ `POST` (optional, for multipart uploads)

### 4.4 Set Destination
- **Destination type:** Lambda function
- **Lambda function:** `parquet-to-postgres-processor`
- Click **Save changes**

### 4.5 Grant Permission
- If prompted, click **Allow** to grant S3 permission to invoke Lambda

---

## Step 5: Configure RDS Security Group (5 minutes)

### 5.1 Go to RDS Console
- Navigate to: https://console.aws.amazon.com/rds
- Click **Databases** → Select your database

### 5.2 Access Security Group
- Click **Connectivity & security** tab
- Under **VPC security groups**, click on the security group link

### 5.3 Edit Inbound Rules
- Click **Edit inbound rules**
- Click **Add rule**
- **Type:** PostgreSQL
- **Port:** `5432`
- **Source:** 
  - For testing: `0.0.0.0/0` (allows all IPs - **not recommended for production**)
  - For production: Use Lambda's security group or specific IP ranges
- Click **Save rules**

**Note:** If Lambda is in a VPC, you need to:
1. Configure Lambda to use the same VPC as RDS
2. Add Lambda's security group to RDS inbound rules

---

## Step 6: Test the Pipeline (5 minutes)

### 6.1 Upload Test File
```bash
# Upload a parquet file to S3
aws s3 cp your-file.parquet s3://YOUR-BUCKET-NAME/

# Or use AWS Console:
# S3 → Your Bucket → Upload → Select parquet file
```

### 6.2 Check Lambda Execution
- Go to Lambda Console
- Click on `parquet-to-postgres-processor`
- Click **Monitor** tab
- Check **Invocations** and **Duration**

### 6.3 View CloudWatch Logs
- Click **View CloudWatch logs**
- Check recent log streams
- Look for:
  - `✓ Connected to PostgreSQL successfully!`
  - `✓ Successfully loaded X rows`

### 6.4 Verify Data in PostgreSQL
```bash
# Connect to RDS
psql -h database-1.c3easrmf.ap-south-1.rds.amazonaws.com \
     -U postgres \
     -d postgres

# Check table
SELECT COUNT(*) FROM audittrail_firehose;
SELECT * FROM audittrail_firehose LIMIT 10;
```

---

## Step 7: Monitor and Optimize (Ongoing)

### 7.1 Set Up CloudWatch Alarms
- Go to CloudWatch → Alarms
- Create alarms for:
  - Lambda errors
  - Lambda duration
  - Lambda throttles

### 7.2 Review Metrics
- Monitor Lambda invocations
- Check execution duration
- Review error rates

### 7.3 Optimize Performance
- Adjust memory if needed
- Increase timeout for large files
- Consider using Lambda Layers for dependencies

---

## ✅ Verification Checklist

- [ ] Lambda function created and deployed
- [ ] Environment variables set correctly
- [ ] S3 event trigger configured
- [ ] RDS security group allows connections
- [ ] Test file uploaded successfully
- [ ] Lambda executed without errors
- [ ] Data appears in PostgreSQL table
- [ ] CloudWatch logs show success messages

---

## 🐛 Common Issues & Solutions

### Issue: Lambda Timeout
**Solution:** Increase timeout to 15 minutes (900 seconds)

### Issue: Memory Error
**Solution:** Increase memory to 3008 MB

### Issue: RDS Connection Failed
**Solution:** 
- Check security group allows Lambda IPs
- Verify RDS endpoint is correct
- Check database credentials

### Issue: S3 Access Denied
**Solution:**
- Verify IAM role has S3 GetObject permission
- Check bucket policy

### Issue: Package Too Large
**Solution:**
- Use Lambda Layers for pyarrow/pandas
- See DEPLOYMENT_GUIDE.md for layer creation

---

## 📞 Next Steps

1. **Set up monitoring:** CloudWatch alarms for errors
2. **Optimize costs:** Use Lambda Layers, adjust memory
3. **Enhance security:** Use Secrets Manager for credentials
4. **Add error handling:** Dead-letter queue for failed executions
5. **Scale:** Consider batch processing for large files

---

## 📚 Additional Resources

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed technical guide
- **[QUICK_START.md](QUICK_START.md)** - Quick reference
- **[README.md](README.md)** - Project overview

---

**Total Estimated Time: ~35 minutes**

**Need Help?** Check CloudWatch logs and verify each step above.

