# How to Upload Deployment Package to Lambda

## Problem
You're getting the error: `Unable to import module 'lambda_function': No module named 'pyarrow'`

This happens because Lambda doesn't have `pyarrow`, `pandas`, and `psycopg2-binary` installed by default. You need to include them in your deployment package.

---

## Solution: Create and Upload Deployment Package

### Option 1: Using PowerShell Script (Recommended - Windows)

1. **Run the script:**
   ```powershell
   .\create-lambda-package.ps1
   ```

2. **Wait for completion** (may take 2-5 minutes to download dependencies)

3. **Upload to Lambda:**
   - Go to AWS Lambda Console
   - Select your function: `parquet-to-postgres-processor`
   - Scroll to **Code source** section
   - Click **Upload from** → **.zip file**
   - Select `lambda-deployment.zip`
   - Wait for upload (may take a few minutes)
   - Click **Deploy** if prompted

4. **Test:**
   - Upload a parquet file to S3
   - Check CloudWatch logs

---

### Option 2: Manual Steps

#### Step 1: Create Deployment Directory
```powershell
mkdir lambda-deployment
cd lambda-deployment
```

#### Step 2: Copy Lambda Function
```powershell
copy ..\lambda_function.py .
```

#### Step 3: Install Dependencies
```powershell
pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t .
```

**Note:** This installs packages to the current directory (`-t .`)

#### Step 4: Create ZIP Package
```powershell
cd ..
Compress-Archive -Path lambda-deployment\* -DestinationPath lambda-deployment.zip -Force
```

#### Step 5: Upload to Lambda
- Go to Lambda Console → Your Function
- Code source → Upload from → .zip file
- Select `lambda-deployment.zip`
- Wait for upload

---

### Option 3: Using AWS CLI

If you have AWS CLI configured:

```powershell
# Create package (use Option 1 or 2 above first)
# Then update function:
aws lambda update-function-code \
    --function-name parquet-to-postgres-processor \
    --zip-file fileb://lambda-deployment.zip
```

---

## Important Notes

### Package Size
- The deployment package will be **~50-100 MB** (pyarrow and pandas are large)
- Lambda has a **50 MB limit** for direct upload
- If your package is >50 MB, you have two options:

#### Option A: Use Lambda Layers (Recommended for Large Packages)

1. **Create Layer Package:**
   ```powershell
   mkdir python
   pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t python/
   Compress-Archive -Path python -DestinationPath lambda-layer.zip
   ```

2. **Upload Layer:**
   - Lambda Console → Layers → Create layer
   - Upload `lambda-layer.zip`
   - Note the Layer ARN

3. **Attach to Function:**
   - Your Function → Layers → Add a layer
   - Select your layer

4. **Create Minimal Function Package:**
   ```powershell
   # Only include lambda_function.py
   Compress-Archive -Path lambda_function.py -DestinationPath lambda-function-only.zip
   ```
   - Upload this smaller package to Lambda

#### Option B: Upload to S3 First (For Packages >50 MB)

1. **Upload ZIP to S3:**
   ```powershell
   aws s3 cp lambda-deployment.zip s3://YOUR-BUCKET-NAME/lambda-deployment.zip
   ```

2. **Update Lambda from S3:**
   ```powershell
   aws lambda update-function-code \
       --function-name parquet-to-postgres-processor \
       --s3-bucket YOUR-BUCKET-NAME \
       --s3-key lambda-deployment.zip
   ```

---

## Verification

After uploading, verify the package:

1. **Check Function Code:**
   - Lambda Console → Your Function → Code
   - You should see `lambda_function.py` and dependency folders

2. **Test Function:**
   - Upload a parquet file to S3
   - Check CloudWatch logs
   - Should see: `✓ Connected to PostgreSQL successfully!`

3. **Check Logs:**
   ```
   CloudWatch → Log groups → /aws/lambda/parquet-to-postgres-processor
   ```

---

## Troubleshooting

### Error: Package too large
- **Solution:** Use Lambda Layers (see Option A above)

### Error: Still can't import module
- **Solution:** 
  1. Verify package includes dependencies
  2. Check folder structure (dependencies should be at root level)
  3. Ensure you're using correct Python runtime (3.9, 3.10, or 3.11)

### Error: Timeout during upload
- **Solution:** 
  1. Upload to S3 first, then update from S3
  2. Or use Lambda Layers

### Error: Memory error after upload
- **Solution:** Increase Lambda memory to 3008 MB

---

## Quick Checklist

- [ ] Created deployment package with dependencies
- [ ] Package size < 50 MB (or using Layers/S3)
- [ ] Uploaded to Lambda function
- [ ] Verified code appears in Lambda console
- [ ] Tested with S3 upload
- [ ] Checked CloudWatch logs for success

---

## Next Steps After Upload

1. **Set Environment Variables** (if not already set):
   - `DB_HOST`, `DB_NAME`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `TABLE_NAME`

2. **Configure Timeout:**
   - 15 minutes (900 seconds)

3. **Configure Memory:**
   - 3008 MB (recommended)

4. **Test:**
   - Upload parquet file to S3
   - Check CloudWatch logs

---

**Need Help?** Check CloudWatch logs for detailed error messages.

