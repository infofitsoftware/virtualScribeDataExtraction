# Quick Fix for Windows Build Error

## The Problem
You're getting compilation errors because Windows is trying to build packages from source, but Lambda needs Linux-compatible packages.

## ✅ EASIEST SOLUTION: Use Lambda Layers

This is the **recommended approach** for Windows users:

### Step 1: Create Layer (Try this first)
```powershell
.\create-lambda-layer.ps1
```

If that fails due to compilation, use **Solution 2** below.

### Step 2: Upload Layer to AWS
1. Go to **Lambda Console** → **Layers** → **Create layer**
2. Upload `lambda-layer.zip`
3. Note the **Layer ARN**

### Step 3: Attach to Your Function
1. Go to your Lambda function
2. **Layers** section → **Add a layer**
3. Select your layer

### Step 4: Upload Function Code
1. Upload `lambda-function-only.zip` (just the function, ~5 KB)
2. Done!

---

## ✅ ALTERNATIVE: Use AWS CloudShell (No Local Build)

If the layer script fails, use AWS CloudShell (free, runs in browser):

### Step 1: Open CloudShell
- Go to AWS Console
- Click **CloudShell** icon (top right)
- Wait for it to open

### Step 2: Upload Files
```bash
# In CloudShell, create directory
mkdir lambda-build
cd lambda-build

# Upload lambda_function.py via CloudShell UI (Actions → Upload file)
```

### Step 3: Build Package
```bash
# Install dependencies
pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t .

# Create ZIP
zip -r lambda-deployment.zip . -x "*.pyc" "__pycache__/*"

# Download the file (Actions → Download file)
```

### Step 4: Upload to Lambda
- Upload `lambda-deployment.zip` to your Lambda function

---

## ✅ ALTERNATIVE: Try Simple Script

Try this simpler script that forces pre-built wheels:

```powershell
.\create-lambda-package-simple.ps1
```

This uses `--only-binary` to avoid compilation.

---

## 🎯 Recommended Order

1. **First:** Try `.\create-lambda-layer.ps1` (Lambda Layers - best option)
2. **If that fails:** Use AWS CloudShell (no local build needed)
3. **Last resort:** Try `.\create-lambda-package-simple.ps1`

---

## Why Lambda Layers?

- ✅ **No compilation needed** - AWS handles it
- ✅ **Reusable** - Use same layer for multiple functions
- ✅ **Smaller function** - Function code is only ~5 KB
- ✅ **Faster deployments** - Update function without re-uploading dependencies
- ✅ **Better for large packages** - pyarrow/pandas are 50-100 MB

---

## Quick Commands

### Create Layer (if script works):
```powershell
.\create-lambda-layer.ps1
```

### Upload Layer via AWS CLI:
```powershell
aws lambda publish-layer-version `
    --layer-name parquet-dependencies `
    --zip-file fileb://lambda-layer.zip `
    --compatible-runtimes python3.9 python3.10 python3.11
```

### Attach Layer to Function:
```powershell
# Get Layer ARN from previous command, then:
aws lambda update-function-configuration `
    --function-name parquet-to-postgres-processor `
    --layers arn:aws:lambda:REGION:ACCOUNT:layer:parquet-dependencies:1
```

---

**Try the Lambda Layer approach first - it's the easiest for Windows users!**

