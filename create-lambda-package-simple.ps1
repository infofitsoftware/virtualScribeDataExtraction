# Simplified PowerShell script - Downloads pre-built wheels directly
# This avoids compilation issues on Windows

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Creating Lambda Package (Simple Method)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will download pre-built wheels to avoid compilation." -ForegroundColor Yellow
Write-Host ""

# Step 1: Clean up
Write-Host "Step 1: Cleaning up..." -ForegroundColor Yellow
if (Test-Path "lambda-deployment") {
    Remove-Item -Recurse -Force "lambda-deployment"
}
if (Test-Path "lambda-deployment.zip") {
    Remove-Item -Force "lambda-deployment.zip"
}

# Step 2: Create directory
Write-Host "Step 2: Creating deployment directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "lambda-deployment" | Out-Null
Set-Location "lambda-deployment"

# Step 3: Copy function
Write-Host "Step 3: Copying Lambda function..." -ForegroundColor Yellow
Copy-Item "..\lambda_function.py" .

# Step 4: Install using pip with --only-binary flag
Write-Host "Step 4: Installing dependencies (pre-built wheels only)..." -ForegroundColor Yellow
Write-Host "  This will only use pre-built wheels, no compilation..." -ForegroundColor Gray

# Install with --only-binary to force pre-built wheels
# This should work if wheels are available for your Python version
pip install --only-binary :all: pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t . 2>&1 | Tee-Object -Variable installOutput

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Installation failed. Trying alternative approach..." -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative Solution: Use Lambda Layers instead" -ForegroundColor Yellow
    Write-Host "See: create-lambda-layer.ps1" -ForegroundColor Yellow
    Set-Location ..
    exit 1
}

Write-Host "  ✓ Dependencies installed" -ForegroundColor Green

# Step 5: Create ZIP
Write-Host "Step 5: Creating ZIP package..." -ForegroundColor Yellow
Set-Location ..

$filesToZip = Get-ChildItem -Path "lambda-deployment" -Recurse | 
    Where-Object { 
        $_.FullName -notmatch "__pycache__" -and
        $_.FullName -notmatch "\.pyc$" -and
        $_.FullName -notmatch "\.dist-info" -and
        $_.FullName -notmatch "\.egg-info"
    }

Compress-Archive -Path $filesToZip.FullName -DestinationPath "lambda-deployment.zip" -Force

$zipSize = (Get-Item "lambda-deployment.zip").Length / 1MB
Write-Host "  ✓ Package created: lambda-deployment.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Package Created!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload lambda-deployment.zip to your Lambda function." -ForegroundColor Yellow

