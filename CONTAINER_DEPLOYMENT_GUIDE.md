# Complete Step-by-Step Guide: Lambda Container Deployment
## For Beginners - Very Detailed Instructions

---

## Prerequisites Checklist

Before starting, make sure you have:
- [ ] AWS Account
- [ ] Docker Desktop installed on your computer ([Download here](https://www.docker.com/products/docker-desktop/))
- [ ] AWS CLI installed ([Download here](https://aws.amazon.com/cli/))
- [ ] Docker Desktop is running (check system tray)

---

## STEP 1: Create ECR Repository (AWS Console)

### 1.1 Open AWS Console
1. Go to: https://console.aws.amazon.com
2. Make sure you're in the **ap-south-1 (Mumbai)** region (top right corner)

### 1.2 Navigate to ECR
1. In the search bar at the top, type: **ECR**
2. Click on **Elastic Container Registry** (or **ECR**)

### 1.3 Create Repository
1. Click the **"Repositories"** link in the left sidebar
2. Click the orange **"Create repository"** button

### 1.4 Configure Repository
1. **Visibility settings:**
   - Select: **Private** (default)

2. **Repository name:**
   - Type: `parquet-processor`
   - (Keep it simple, lowercase, no spaces)

3. **Tag immutability:**
   - Leave as default (Tag immutability: Disabled)

4. **Scan settings:**
   - Leave as default (can enable later if needed)

5. **Encryption:**
   - Leave as default (AWS managed encryption)

6. Click **"Create repository"** at the bottom

### 1.5 Note Your Repository URI
After creation, you'll see a page with repository details. **Copy the URI** - it looks like:
```
YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor
```
**Save this somewhere - you'll need it later!**

---

## STEP 2: Create Dockerfile

### 2.1 Check Your Files
Make sure you have `lambda_function.py` in your project folder:
```
C:\Users\anilu\Projects\virtualScribe\
├── lambda_function.py  ← Must be here
└── Dockerfile          ← We'll create this
```

### 2.2 Create Dockerfile
1. In your project folder, create a new file named: `Dockerfile`
   - **Important:** No extension! Just `Dockerfile` (not `Dockerfile.txt`)

2. Open `Dockerfile` in a text editor (Notepad, VS Code, etc.)

3. Copy and paste this exact content:

```dockerfile
FROM public.ecr.aws/lambda/python:3.11

# Install dependencies
RUN pip install --no-cache-dir pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9

# Copy Lambda function
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "lambda_function.lambda_handler" ]
```

4. **Save the file**

**Note:** I've already created this file for you as `Dockerfile` in your project folder.

---

## STEP 3: Push Docker Image to ECR

### 3.1 Open Command Prompt or PowerShell
- Press `Windows Key + R`
- Type: `powershell` or `cmd`
- Press Enter

### 3.2 Navigate to Your Project Folder
```powershell
cd C:\Users\anilu\Projects\virtualScribe
```

### 3.3 Verify Docker is Running
```powershell
docker --version
```
You should see Docker version. If you get an error, **start Docker Desktop** first.

### 3.4 Configure AWS CLI (If Not Already Done)
**Important:** The ECR login uses AWS CLI credentials (Access Keys), NOT your console username/password.

If you haven't configured AWS CLI yet:
1. Open PowerShell
2. Run: `aws configure`
3. Enter:
   - **AWS Access Key ID:** (Get from IAM → Users → Your User → Security Credentials → Create Access Key)
   - **AWS Secret Access Key:** (From same place)
   - **Default region:** `ap-south-1`
   - **Default output format:** `json`

**To create Access Keys:**
- Go to IAM Console → Users → Your User (anish)
- Security credentials tab → Create access key
- Download and save the keys securely

### 3.5 Get Your AWS Account ID
**To find your Account ID:**
- Click your name in top right of AWS Console
- Your Account ID is shown there (12 digits)
- **Example:** `123456789012`

### 3.6 Get ECR Login Token
Replace `YOUR-ACCOUNT-ID` with your actual AWS account ID (12 digits).

**The command format:**
```powershell
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com
```

**Example (replace 123456789012 with YOUR account ID):**
```powershell
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

**Note:** This uses AWS CLI credentials (from `aws configure`), NOT your console username/password.

You should see: `Login Succeeded`

### 3.5 Build Docker Image
```powershell
docker build -t parquet-processor .
```

**What this does:**
- `docker build` = build the image
- `-t parquet-processor` = tag/name it "parquet-processor"
- `.` = use current folder (where Dockerfile is)

**This will take 5-10 minutes** - it's downloading and installing everything.

### 3.6 Tag the Image for ECR
Replace `YOUR-ACCOUNT-ID` with your account ID:

```powershell
docker tag parquet-processor:latest YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest
```

**Example:**
```powershell
docker tag parquet-processor:latest 123456789012.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest
```

### 3.7 Push Image to ECR
Replace `YOUR-ACCOUNT-ID` with your account ID:

```powershell
docker push YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest
```

**Example:**
```powershell
docker push 123456789012.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest
```

**This will take 5-15 minutes** - it's uploading the image (it's large).

### 3.8 Verify in AWS Console
1. Go back to ECR Console
2. Click on `parquet-processor` repository
3. You should see your image with tag `latest`

---

## STEP 4: Deploy to Lambda

### 4.1 Go to Lambda Console
1. Go to: https://console.aws.amazon.com/lambda
2. Make sure you're in **ap-south-1 (Mumbai)** region

### 4.2 Select Your Function
1. Click on your existing function: `parquet-to-postgres-processor`
   - (Or whatever you named it)

### 4.3 Switch to Container Image
1. Scroll down to **"Code source"** section
2. Look for **"Image"** tab (next to "Code" tab)
3. Click **"Image"** tab
4. Click **"Deploy new image"**

### 4.4 Select Container Image
1. Click **"Browse images"**
2. Select your repository: `parquet-processor`
3. Select the image tag: `latest`
4. Click **"Select image"**

### 4.5 Deploy
1. Click **"Deploy"** button
2. Wait for deployment (1-2 minutes)

### 4.6 Configure Settings (Important!)
1. Click **"Configuration"** tab
2. Click **"General configuration"** → **"Edit"**
3. Set:
   - **Timeout:** `15 min 0 sec` (900 seconds)
   - **Memory:** `3008 MB` (or maximum available)
4. Click **"Save"**

### 4.7 Set Environment Variables
1. Still in **Configuration** tab
2. Click **"Environment variables"** → **"Edit"**
3. Add/verify these variables:

| Key | Value |
|-----|-------|
| `DB_HOST` | `database-1.c3easrmf.ap-south-1.rds.amazonaws.com` |
| `DB_NAME` | `postgres` |
| `DB_PORT` | `5432` |
| `DB_USER` | `postgres` |
| `DB_PASSWORD` | `Dashboard6287` |
| `TABLE_NAME` | `audittrail_firehose` |

4. Click **"Save"**

---

## STEP 5: Test Your Function

### 5.1 Upload Test File to S3
1. Go to your S3 bucket
2. Upload a parquet file
3. Wait a few seconds

### 5.2 Check CloudWatch Logs
1. In Lambda Console, click **"Monitor"** tab
2. Click **"View CloudWatch logs"**
3. Check recent log streams
4. Look for: `✓ Connected to PostgreSQL successfully!`

### 5.3 Verify Data in PostgreSQL
Connect to your RDS database and check:
```sql
SELECT COUNT(*) FROM audittrail_firehose;
```

---

## Troubleshooting

### Docker Login Failed
- **Error:** "Unable to locate credentials"
- **Fix:** Run `aws configure` first to set up AWS credentials

### Docker Build Failed
- **Error:** "Cannot connect to Docker daemon"
- **Fix:** Make sure Docker Desktop is running

### Push Failed
- **Error:** "denied: Your Authorization Token has expired"
- **Fix:** Run the login command again (Step 3.4)

### Lambda Can't Find Image
- **Error:** "Image not found"
- **Fix:** Make sure you selected the correct repository and tag

### Function Times Out
- **Fix:** Increase timeout to 15 minutes (Step 4.6)

---

## Quick Command Reference

```powershell
# 1. Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com

# 2. Build image
docker build -t parquet-processor .

# 3. Tag image
docker tag parquet-processor:latest YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest

# 4. Push image
docker push YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com/parquet-processor:latest
```

---

## Summary Checklist

- [ ] Created ECR repository named `parquet-processor`
- [ ] Created `Dockerfile` in project folder
- [ ] Built Docker image successfully
- [ ] Pushed image to ECR
- [ ] Updated Lambda to use container image
- [ ] Set timeout to 15 minutes
- [ ] Set memory to 3008 MB
- [ ] Set all environment variables
- [ ] Tested with S3 upload
- [ ] Verified data in PostgreSQL

---

**That's it!** Your Lambda function is now running as a container with all dependencies included.

