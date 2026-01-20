# Important: ECR Login Credentials Explained

## ⚠️ Important Clarification

The ECR login command **does NOT use** your AWS Console username/password (anish/abc@123).

It uses **AWS CLI credentials** (Access Key ID and Secret Access Key).

---

## What You Need

### 1. AWS Account ID (12 digits)
- Click your name in top right of AWS Console
- Your Account ID is shown there
- **Example:** `123456789012`

### 2. AWS CLI Access Keys
These are different from your console login credentials.

---

## Step-by-Step: Get Access Keys

### Step 1: Go to IAM Console
1. AWS Console → Search "IAM"
2. Click **Users** in left sidebar
3. Click on your user: **anish**

### Step 2: Create Access Key
1. Click **Security credentials** tab
2. Scroll to **Access keys** section
3. Click **Create access key**
4. Select use case: **Command Line Interface (CLI)**
5. Click **Next** → **Create access key**

### Step 3: Save Your Keys
**IMPORTANT:** Download or copy these immediately - you can only see them once!

- **Access Key ID:** (looks like: `AKIAIOSFODNN7EXAMPLE`)
- **Secret Access Key:** (looks like: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)

**Save these securely!**

---

## Configure AWS CLI

### Step 1: Open PowerShell
Press `Windows Key + R`, type `powershell`, press Enter

### Step 2: Run AWS Configure
```powershell
aws configure
```

### Step 3: Enter Your Credentials
When prompted, enter:

```
AWS Access Key ID: [Paste your Access Key ID from Step 3 above]
AWS Secret Access Key: [Paste your Secret Access Key from Step 3 above]
Default region name: ap-south-1
Default output format: json
```

---

## Now You Can Login to ECR

### Step 1: Get Your Account ID
- Click your name in AWS Console (top right)
- Note your 12-digit Account ID

### Step 2: Run ECR Login Command
Replace `YOUR-ACCOUNT-ID` with your actual 12-digit account ID:

```powershell
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin YOUR-ACCOUNT-ID.dkr.ecr.ap-south-1.amazonaws.com
```

**Example (if your account ID is 123456789012):**
```powershell
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

You should see: `Login Succeeded`

---

## Summary

1. ✅ Get AWS Account ID (from console top right)
2. ✅ Create Access Keys (IAM → Users → anish → Security credentials)
3. ✅ Configure AWS CLI (`aws configure`)
4. ✅ Run ECR login command with your Account ID

---

## Quick Reference

**Your console login (anish/abc@123)** = For AWS Console website  
**AWS CLI credentials (Access Keys)** = For command line tools like Docker/ECR

These are **different** credentials!

---

**Need help?** Make sure:
- AWS CLI is installed (`aws --version`)
- Access keys are created in IAM
- AWS CLI is configured (`aws configure`)
- Docker Desktop is running

