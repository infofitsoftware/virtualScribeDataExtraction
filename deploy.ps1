# PowerShell Deployment Script for Lambda Function
# Usage: .\deploy.ps1 [function-name] [bucket-name]

param(
    [string]$FunctionName = "parquet-to-postgres-processor",
    [string]$BucketName = ""
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Lambda Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Function Name: $FunctionName" -ForegroundColor Yellow
Write-Host ""

# Step 1: Create deployment directory
Write-Host "Step 1: Preparing deployment package..." -ForegroundColor Yellow
if (Test-Path "lambda-deployment") {
    Remove-Item -Recurse -Force "lambda-deployment"
}
New-Item -ItemType Directory -Path "lambda-deployment" | Out-Null
Set-Location "lambda-deployment"

# Step 2: Install dependencies
Write-Host "Step 2: Installing dependencies..." -ForegroundColor Yellow
pip install -r ..\requirements-lambda.txt -t . --quiet

# Step 3: Copy Lambda function
Write-Host "Step 3: Copying Lambda function..." -ForegroundColor Yellow
Copy-Item "..\lambda_function.py" .

# Step 4: Create deployment package
Write-Host "Step 4: Creating deployment package..." -ForegroundColor Yellow
Set-Location ..
Get-ChildItem -Path "lambda-deployment" -Recurse | 
    Where-Object { $_.Name -notmatch "(__pycache__|\.pyc|\.dist-info|\.egg-info)" } |
    Compress-Archive -DestinationPath "lambda-deployment.zip" -Force

Write-Host "✓ Deployment package created: lambda-deployment.zip" -ForegroundColor Green

# Step 5: Check if function exists
Write-Host "Step 5: Checking if function exists..." -ForegroundColor Yellow
try {
    $null = aws lambda get-function --function-name $FunctionName 2>&1
    Write-Host "Function exists. Updating..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file fileb://lambda-deployment.zip
    
    Write-Host "✓ Function code updated" -ForegroundColor Green
} catch {
    Write-Host "Function does not exist. Please create it first using AWS Console or CLI." -ForegroundColor Yellow
    Write-Host "See DEPLOYMENT_GUIDE.md for instructions." -ForegroundColor Yellow
}

# Step 6: Display environment variables reminder
Write-Host "Step 6: Verifying environment variables..." -ForegroundColor Yellow
Write-Host "Make sure to set these in Lambda console:" -ForegroundColor Yellow
Write-Host "  DB_HOST=database-1.c3easrmf.ap-south-1.rds.amazonaws.com"
Write-Host "  DB_NAME=postgres"
Write-Host "  DB_PORT=5432"
Write-Host "  DB_USER=postgres"
Write-Host "  DB_PASSWORD=Dashboard6287"
Write-Host "  TABLE_NAME=audittrail_firehose"

# Step 7: Configure S3 trigger (if bucket name provided)
if ($BucketName) {
    Write-Host "Step 7: Configuring S3 trigger for bucket: $BucketName" -ForegroundColor Yellow
    
    $FunctionArn = aws lambda get-function --function-name $FunctionName --query 'Configuration.FunctionArn' --output text
    $AccountId = aws sts get-caller-identity --query Account --output text
    
    # Add permission for S3 to invoke Lambda
    try {
        aws lambda add-permission `
            --function-name $FunctionName `
            --principal s3.amazonaws.com `
            --statement-id s3-trigger-permission `
            --action "lambda:InvokeFunction" `
            --source-arn "arn:aws:s3:::$BucketName" `
            --source-account $AccountId 2>&1 | Out-Null
        Write-Host "✓ S3 trigger permission added" -ForegroundColor Green
    } catch {
        Write-Host "Permission may already exist" -ForegroundColor Yellow
    }
    
    Write-Host "Note: You still need to configure the S3 event notification in the S3 console." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Verify environment variables in Lambda console"
Write-Host "2. Configure S3 event notification"
Write-Host "3. Test by uploading a parquet file to S3"
Write-Host "4. Check CloudWatch logs for execution details"

