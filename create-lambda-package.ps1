# PowerShell script to create Lambda deployment package with dependencies
# Run this script to create a deployment package that includes all required modules

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Creating Lambda Deployment Package" -ForegroundColor Cyan
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

# Step 4: Install dependencies
Write-Host "Step 4: Installing dependencies (this may take a few minutes)..." -ForegroundColor Yellow
Write-Host "  Installing pyarrow, pandas, psycopg2-binary..." -ForegroundColor Gray

# Install dependencies to current directory
pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t . --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install dependencies. Please check your pip installation." -ForegroundColor Red
    Set-Location ..
    exit 1
}

Write-Host "  ✓ Dependencies installed successfully" -ForegroundColor Green

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
Write-Host "      If it's too large (>50MB), consider using Lambda Layers (see DEPLOYMENT_GUIDE.md)" -ForegroundColor Cyan

