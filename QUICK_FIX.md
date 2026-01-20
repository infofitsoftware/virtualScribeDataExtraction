# Quick Fix: Missing pyarrow Module Error

## The Problem
```
[ERROR] Runtime.ImportModuleError: Unable to import module 'lambda_function': No module named 'pyarrow'
```

## The Solution
You need to upload a deployment package that includes all dependencies (pyarrow, pandas, psycopg2-binary).

---

## 🚀 Quick Fix (3 Steps)

### Step 1: Create Package with Dependencies

**Windows (PowerShell):**
```powershell
.\create-lambda-package.ps1
```

**Linux/Mac:**
```bash
chmod +x create-lambda-package.sh
./create-lambda-package.sh
```

**OR Manual (if scripts don't work):**
```powershell
# Create directory
mkdir lambda-deployment
cd lambda-deployment

# Copy function
copy ..\lambda_function.py .    # Windows
# OR
cp ../lambda_function.py .      # Linux/Mac

# Install dependencies
pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t .

# Create ZIP
cd ..
Compress-Archive -Path lambda-deployment\* -DestinationPath lambda-deployment.zip -Force    # Windows
# OR
zip -r lambda-deployment.zip lambda-deployment/    # Linux/Mac
```

### Step 2: Upload to Lambda

1. Go to **AWS Lambda Console**
2. Click on your function: `parquet-to-postgres-processor`
3. Scroll to **Code source** section
4. Click **Upload from** → **.zip file**
5. Select `lambda-deployment.zip`
6. **Wait for upload** (may take 2-5 minutes)
7. Click **Deploy** if button appears

### Step 3: Test

1. Upload a parquet file to your S3 bucket
2. Check CloudWatch logs
3. Should see: `✓ Connected to PostgreSQL successfully!`

---

## ⚠️ Important Notes

### Package Size Warning
- The package will be **~50-100 MB** (pyarrow and pandas are large)
- Lambda has a **50 MB limit** for direct ZIP upload

### If Package is Too Large (>50 MB)

**Option 1: Upload via S3 (Recommended)**
```powershell
# Upload ZIP to S3 first
aws s3 cp lambda-deployment.zip s3://YOUR-BUCKET-NAME/lambda-deployment.zip

# Update Lambda from S3
aws lambda update-function-code \
    --function-name parquet-to-postgres-processor \
    --s3-bucket YOUR-BUCKET-NAME \
    --s3-key lambda-deployment.zip
```

**Option 2: Use Lambda Layers**
See `UPLOAD_TO_LAMBDA.md` for detailed instructions on using Lambda Layers.

---

## ✅ Verification

After uploading, check:

1. **Lambda Console → Code:**
   - You should see `lambda_function.py`
   - You should see folders like `pyarrow`, `pandas`, `psycopg2`

2. **Test Upload:**
   - Upload parquet file to S3
   - Check CloudWatch logs
   - No more "No module named 'pyarrow'" error

3. **Success Indicators:**
   ```
   ✓ Connected to PostgreSQL successfully!
   ✓ Successfully loaded X rows
   ```

---

## 🐛 Still Having Issues?

1. **Check Package Contents:**
   - Unzip `lambda-deployment.zip`
   - Verify `pyarrow` folder exists
   - Verify `lambda_function.py` is at root level

2. **Check Lambda Runtime:**
   - Should be Python 3.9, 3.10, or 3.11
   - Go to Configuration → General configuration

3. **Check CloudWatch Logs:**
   - Look for detailed error messages
   - Check import statements

4. **Verify Environment Variables:**
   - DB_HOST, DB_NAME, DB_PORT, DB_USER, DB_PASSWORD, TABLE_NAME

---

## 📋 Checklist

- [ ] Created deployment package with dependencies
- [ ] Package includes pyarrow, pandas, psycopg2-binary
- [ ] Uploaded ZIP to Lambda function
- [ ] Verified code appears in Lambda console
- [ ] Tested with S3 upload
- [ ] Checked CloudWatch logs - no import errors

---

**That's it!** Your Lambda function should now work correctly.

