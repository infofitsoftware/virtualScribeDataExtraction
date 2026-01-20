# Fix: Building Lambda Package on Windows

## The Problem
When building the Lambda package on Windows, you're getting compilation errors because:
1. Lambda runs on **Linux**, but you're building on **Windows**
2. Some packages (like numpy) need to be compiled from source if no pre-built wheel exists
3. Compilation requires C compilers (Visual Studio, GCC, etc.) which may not be installed

## Solutions (Choose One)

---

## ✅ Solution 1: Use Pre-Built Wheels (Easiest)

### Try this script first:
```powershell
.\create-lambda-package-simple.ps1
```

This uses `--only-binary :all:` to force pip to only use pre-built wheels.

**If this works:** You're done! Upload `lambda-deployment.zip` to Lambda.

**If this fails:** Try Solution 2 or 3.

---

## ✅ Solution 2: Use Lambda Layers (Recommended)

Layers are better for large packages like pyarrow/pandas:

### Step 1: Create Layer
```powershell
.\create-lambda-layer.ps1
```

### Step 2: Upload Layer to Lambda
1. Go to **Lambda Console** → **Layers** → **Create layer**
2. Upload `lambda-layer.zip`
3. Note the **Layer ARN**

### Step 3: Attach Layer to Function
1. Go to your Lambda function
2. Scroll to **Layers** section
3. Click **Add a layer**
4. Select your layer

### Step 4: Upload Function Code Only
1. Upload `lambda-function-only.zip` (just the function, no dependencies)
2. This is much smaller (~5 KB vs 50-100 MB)

**Benefits:**
- ✅ Reusable across multiple functions
- ✅ Smaller function package
- ✅ Faster deployments
- ✅ Better for large dependencies

---

## ✅ Solution 3: Use Docker (Best for Complex Builds)

If you have Docker installed, build in a Linux container:

### Step 1: Create Dockerfile
```dockerfile
FROM public.ecr.aws/lambda/python:3.11

# Install dependencies
RUN pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t /var/task

# Copy function
COPY lambda_function.py /var/task/

# Create deployment package
RUN cd /var/task && zip -r /tmp/lambda-deployment.zip . -x "*.pyc" "__pycache__/*"
```

### Step 2: Build and Extract
```powershell
# Build Docker image
docker build -t lambda-builder .

# Extract the ZIP file
docker run --rm -v ${PWD}:/output lambda-builder cp /tmp/lambda-deployment.zip /output/
```

### Step 3: Upload to Lambda
Upload `lambda-deployment.zip` to your Lambda function.

---

## ✅ Solution 4: Use AWS CloudShell or EC2 Linux Instance

Build on a Linux machine (CloudShell is free):

### Using AWS CloudShell:
1. Go to **AWS CloudShell** (top right in AWS Console)
2. Upload your files:
   ```bash
   # In CloudShell
   mkdir lambda-build
   cd lambda-build
   # Upload lambda_function.py via CloudShell UI
   ```
3. Run:
   ```bash
   pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t .
   zip -r lambda-deployment.zip . -x "*.pyc" "__pycache__/*"
   ```
4. Download `lambda-deployment.zip`

---

## ✅ Solution 5: Download Pre-Built Packages Manually

### Step 1: Download Wheels
Go to PyPI and download Linux wheels:
- https://pypi.org/project/pyarrow/#files (look for `manylinux` wheels)
- https://pypi.org/project/pandas/#files
- https://pypi.org/project/psycopg2-binary/#files

### Step 2: Extract and Package
```powershell
mkdir lambda-deployment
cd lambda-deployment
# Extract downloaded wheels here
copy ..\lambda_function.py .
cd ..
Compress-Archive -Path lambda-deployment\* -DestinationPath lambda-deployment.zip
```

---

## ✅ Solution 6: Use AWS SAM or Serverless Framework

These tools handle cross-platform builds automatically:

### Using AWS SAM:
```bash
sam build
sam package
sam deploy
```

### Using Serverless Framework:
```bash
serverless deploy
```

---

## 🎯 Recommended Approach

**For Windows users, I recommend:**

1. **First try:** `.\create-lambda-package-simple.ps1` (Solution 1)
2. **If that fails:** Use Lambda Layers (Solution 2) - **Best option**
3. **If you have Docker:** Use Docker (Solution 3)
4. **If nothing works:** Use AWS CloudShell (Solution 4)

---

## Quick Comparison

| Method | Difficulty | Time | Best For |
|--------|-----------|------|----------|
| Pre-built wheels | ⭐ Easy | 2 min | Simple cases |
| Lambda Layers | ⭐⭐ Medium | 5 min | **Recommended** |
| Docker | ⭐⭐⭐ Hard | 10 min | Complex builds |
| CloudShell | ⭐⭐ Medium | 5 min | No local setup |

---

## Still Having Issues?

1. **Check Python version:** Lambda supports 3.9, 3.10, 3.11
2. **Check pip version:** `pip install --upgrade pip`
3. **Try different package versions:** Sometimes newer versions have better wheel support
4. **Use Lambda Layers:** This is the most reliable method for Windows users

---

## Next Steps After Building

1. Upload package to Lambda
2. Set environment variables
3. Configure timeout (15 min) and memory (3008 MB)
4. Test with S3 upload
5. Check CloudWatch logs

---

**Need more help?** Check CloudWatch logs for specific error messages.

