# Create Lambda Layer for dependencies (Recommended for large packages)
# Layers are better for pyarrow/pandas as they're large and reusable

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Creating Lambda Layer (Recommended)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This creates a Lambda Layer with dependencies." -ForegroundColor Yellow
Write-Host "Then you only need to upload lambda_function.py to Lambda." -ForegroundColor Yellow
Write-Host ""

# Step 1: Clean up
Write-Host "Step 1: Cleaning up..." -ForegroundColor Yellow
if (Test-Path "python") {
    Remove-Item -Recurse -Force "python"
}
if (Test-Path "lambda-layer.zip") {
    Remove-Item -Force "lambda-layer.zip"
}

# Step 2: Create python directory (Lambda Layer structure)
Write-Host "Step 2: Creating layer structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "python" | Out-Null
Set-Location "python"

# Step 3: Install dependencies
Write-Host "Step 3: Installing dependencies to layer..." -ForegroundColor Yellow
Write-Host "  Installing pyarrow, pandas, psycopg2-binary..." -ForegroundColor Gray

# Try installing with --only-binary first
pip install --only-binary :all: pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t . 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Installation with --only-binary failed." -ForegroundColor Red
    Write-Host "  Trying without --only-binary flag..." -ForegroundColor Yellow
    
    # If that fails, try without the flag (may need to build)
    pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t . 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Could not install dependencies." -ForegroundColor Red
        Write-Host ""
        Write-Host "SOLUTION: Use Docker or Linux machine to build the layer." -ForegroundColor Yellow
        Write-Host "See: create-lambda-layer-docker.sh" -ForegroundColor Yellow
        Set-Location ..
        exit 1
    }
}

Write-Host "  ✓ Dependencies installed" -ForegroundColor Green

# Step 4: Create layer ZIP
Write-Host "Step 4: Creating layer ZIP..." -ForegroundColor Yellow
Set-Location ..

Compress-Archive -Path "python" -DestinationPath "lambda-layer.zip" -Force

$layerSize = (Get-Item "lambda-layer.zip").Length / 1MB
Write-Host "  ✓ Layer created: lambda-layer.zip ($([math]::Round($layerSize, 2)) MB)" -ForegroundColor Green

# Step 5: Create function-only package
Write-Host "Step 5: Creating function-only package..." -ForegroundColor Yellow
Compress-Archive -Path "lambda_function.py" -DestinationPath "lambda-function-only.zip" -Force

$funcSize = (Get-Item "lambda-function-only.zip").Length / 1KB
Write-Host "  ✓ Function package created: lambda-function-only.zip ($([math]::Round($funcSize, 2)) KB)" -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Layer Created Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to Lambda Console -> Layers -> Create layer" -ForegroundColor White
Write-Host "2. Upload lambda-layer.zip" -ForegroundColor White
Write-Host "3. Note the Layer ARN" -ForegroundColor White
Write-Host "4. Go to your Lambda function" -ForegroundColor White
Write-Host "5. Add the layer to your function" -ForegroundColor White
Write-Host "6. Upload lambda-function-only.zip as function code" -ForegroundColor White
Write-Host ""
Write-Host "OR use AWS CLI:" -ForegroundColor Cyan
Write-Host '  aws lambda publish-layer-version --layer-name parquet-dependencies --zip-file fileb://lambda-layer.zip' -ForegroundColor Gray
Write-Host '  aws lambda update-function-code --function-name YOUR-FUNCTION --zip-file fileb://lambda-function-only.zip' -ForegroundColor Gray

