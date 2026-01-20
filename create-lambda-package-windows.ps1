# PowerShell script to create Lambda deployment package with dependencies
# This version uses pre-built wheels to avoid compilation issues on Windows

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Creating Lambda Deployment Package (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean up any existing deployment directory
Write-Host "Step 1: Cleaning up old deployment files..." -ForegroundColor Yellow
if (Test-Path "lambda-deployment") {
    Remove-Item -Recurse -Force "lambda-deployment"
}
if (Test-Path "lambda-deployment.zip") {
    Remove-Item -Force "lambda-deployment.zip"
}

# Step 2: Create deployment directory
Write-Host "Step 2: Creating deployment directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "lambda-deployment" | Out-Null
Set-Location "lambda-deployment"

# Step 3: Copy Lambda function
Write-Host "Step 3: Copying Lambda function..." -ForegroundColor Yellow
Copy-Item "..\lambda_function.py" .

# Step 4: Install dependencies using pre-built wheels
Write-Host "Step 4: Installing dependencies (this may take a few minutes)..." -ForegroundColor Yellow
Write-Host "  Using pre-built wheels for Linux (Lambda environment)..." -ForegroundColor Gray

# Install dependencies with platform-specific wheels
# Use --platform to get Linux wheels, and --only-binary to avoid building from source
$env:PIP_ONLY_BINARY = "all"

# Try installing with platform specification for Linux (manylinux)
Write-Host "  Installing psycopg2-binary (no compilation needed)..." -ForegroundColor Gray
pip install psycopg2-binary==2.9.9 -t . --only-binary :all: --platform manylinux2014_x86_64 --target-platform manylinux2014_x86_64 --no-deps 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Trying alternative method for psycopg2-binary..." -ForegroundColor Yellow
    pip install psycopg2-binary==2.9.9 -t . --only-binary :all: 2>&1 | Out-Null
}

Write-Host "  Installing pandas (pre-built wheel)..." -ForegroundColor Gray
pip install pandas==2.1.4 -t . --only-binary :all: --platform manylinux2014_x86_64 --target-platform manylinux2014_x86_64 --no-deps 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Trying alternative method for pandas..." -ForegroundColor Yellow
    pip install pandas==2.1.4 -t . --only-binary :all: 2>&1 | Out-Null
}

Write-Host "  Installing pyarrow (pre-built wheel)..." -ForegroundColor Gray
pip install pyarrow==14.0.1 -t . --only-binary :all: --platform manylinux2014_x86_64 --target-platform manylinux2014_x86_64 --no-deps 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Trying alternative method for pyarrow..." -ForegroundColor Yellow
    pip install pyarrow==14.0.1 -t . --only-binary :all: 2>&1 | Out-Null
}

# Install numpy as dependency (required by pandas/pyarrow)
Write-Host "  Installing numpy (dependency)..." -ForegroundColor Gray
pip install numpy==1.26.4 -t . --only-binary :all: --platform manylinux2014_x86_64 --target-platform manylinux2014_x86_64 --no-deps 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Trying alternative method for numpy..." -ForegroundColor Yellow
    pip install numpy==1.26.4 -t . --only-binary :all: 2>&1 | Out-Null
}

# Install other dependencies
Write-Host "  Installing additional dependencies..." -ForegroundColor Gray
pip install python-dateutil pytz -t . --only-binary :all: 2>&1 | Out-Null

Write-Host "  ✓ Dependencies installed" -ForegroundColor Green

# Step 5: Create ZIP package
Write-Host "Step 5: Creating ZIP package..." -ForegroundColor Yellow
Set-Location ..

# Get all files except cache and unnecessary files
$filesToZip = Get-ChildItem -Path "lambda-deployment" -Recurse | 
    Where-Object { 
        $_.FullName -notmatch "__pycache__" -and
        $_.FullName -notmatch "\.pyc$" -and
        $_.FullName -notmatch "\.dist-info" -and
        $_.FullName -notmatch "\.egg-info" -and
        $_.FullName -notmatch "test" -and
        $_.FullName -notmatch "tests"
    }

# Create ZIP file
Compress-Archive -Path $filesToZip.FullName -DestinationPath "lambda-deployment.zip" -Force

# Get file size
$zipSize = (Get-Item "lambda-deployment.zip").Length / 1MB
Write-Host "  ✓ Package created: lambda-deployment.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Package Created Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to AWS Lambda Console" -ForegroundColor White
Write-Host "2. Select your Lambda function" -ForegroundColor White
Write-Host "3. Click 'Upload from' -> '.zip file'" -ForegroundColor White
Write-Host "4. Upload 'lambda-deployment.zip'" -ForegroundColor White
Write-Host "5. Wait for upload to complete" -ForegroundColor White
Write-Host "6. Test your function" -ForegroundColor White
Write-Host ""
Write-Host "Note: The package size is ~$([math]::Round($zipSize, 2)) MB" -ForegroundColor Cyan
if ($zipSize -gt 50) {
    Write-Host "WARNING: Package is >50MB. Upload to S3 first, then update Lambda from S3." -ForegroundColor Red
    Write-Host "See UPLOAD_TO_LAMBDA.md for S3 upload instructions." -ForegroundColor Yellow
}

