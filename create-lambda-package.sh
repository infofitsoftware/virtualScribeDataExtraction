#!/bin/bash
# Bash script to create Lambda deployment package with dependencies
# Run this script to create a deployment package that includes all required modules

set -e

echo "=========================================="
echo "Creating Lambda Deployment Package"
echo "=========================================="
echo ""

# Step 1: Clean up any existing deployment directory
echo "Step 1: Cleaning up old deployment files..."
rm -rf lambda-deployment
rm -f lambda-deployment.zip

# Step 2: Create deployment directory
echo "Step 2: Creating deployment directory..."
mkdir -p lambda-deployment
cd lambda-deployment

# Step 3: Copy Lambda function
echo "Step 3: Copying Lambda function..."
cp ../lambda_function.py .

# Step 4: Install dependencies
echo "Step 4: Installing dependencies (this may take a few minutes)..."
echo "  Installing pyarrow, pandas, psycopg2-binary..."

# Install dependencies to current directory
pip install pyarrow==14.0.1 pandas==2.1.4 psycopg2-binary==2.9.9 -t . --quiet

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install dependencies. Please check your pip installation."
    cd ..
    exit 1
fi

echo "  ✓ Dependencies installed successfully"

# Step 5: Create ZIP package
echo "Step 5: Creating ZIP package..."
cd ..

# Create ZIP excluding unnecessary files
zip -r lambda-deployment.zip lambda-deployment/ \
    -x "*.pyc" \
    -x "__pycache__/*" \
    -x "*.dist-info/*" \
    -x "*.egg-info/*" \
    -x "*/test/*" \
    -x "*/tests/*" \
    -q

# Get file size
ZIP_SIZE=$(du -h lambda-deployment.zip | cut -f1)
echo "  ✓ Package created: lambda-deployment.zip ($ZIP_SIZE)"

echo ""
echo "=========================================="
echo "Package Created Successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Go to AWS Lambda Console"
echo "2. Select your Lambda function"
echo "3. Click 'Upload from' -> '.zip file'"
echo "4. Upload 'lambda-deployment.zip'"
echo "5. Wait for upload to complete"
echo "6. Test your function"
echo ""
echo "Note: If package is >50MB, consider using Lambda Layers"
echo "      See UPLOAD_TO_LAMBDA.md for details"

