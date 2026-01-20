# Parquet to PostgreSQL Data Pipeline

This project provides a complete solution for automatically processing parquet files uploaded to S3 and loading them into RDS PostgreSQL using AWS Lambda.

## 📁 Project Structure

```
.
├── lambda_function.py          # Main Lambda handler (S3 → RDS)
├── analyze_parquet_schema.py   # Local schema analysis tool
├── load_parquet_to_postgres.py # Local data loading tool
├── requirements.txt            # Local development dependencies
├── requirements-lambda.txt     # Lambda deployment dependencies
├── deploy.sh                   # Linux/Mac deployment script
├── deploy.ps1                  # Windows PowerShell deployment script
├── test-event.json            # Sample S3 event for testing
├── DEPLOYMENT_GUIDE.md        # Detailed deployment instructions
├── QUICK_START.md             # Quick reference checklist
└── README.md                  # This file
```

## 🚀 Quick Start

### For Local Development

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Analyze parquet schema:**
   ```bash
   python analyze_parquet_schema.py
   ```

3. **Load data to local PostgreSQL:**
   ```bash
   python load_parquet_to_postgres.py
   ```

### For AWS Lambda Deployment

See **[QUICK_START.md](QUICK_START.md)** for a quick checklist or **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** for detailed instructions.

**TL;DR:**
1. Create IAM role with S3 and RDS permissions
2. Run `./deploy.sh` (or `.\deploy.ps1` on Windows)
3. Create Lambda function in AWS Console
4. Configure S3 event trigger
5. Set RDS security group rules
6. Test!

## 🏗️ Architecture

```
┌─────────────┐
│  S3 Bucket  │
│ (Parquet)   │
└──────┬──────┘
       │ Upload
       │ Triggers
       ▼
┌─────────────┐
│AWS Lambda   │
│ Function    │
│             │
│ 1. Download │
│ 2. Analyze  │
│ 3. Load     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ RDS         │
│ PostgreSQL  │
└─────────────┘
```

## 📋 Features

- ✅ **Automatic Processing:** Triggers on S3 parquet file uploads
- ✅ **Schema Detection:** Automatically analyzes and maps parquet schemas
- ✅ **Type Mapping:** Converts Arrow/Parquet types to PostgreSQL types
- ✅ **Table Creation:** Auto-creates PostgreSQL tables if they don't exist
- ✅ **Batch Loading:** Efficient batch inserts for large files
- ✅ **Error Handling:** Comprehensive error handling and logging
- ✅ **CloudWatch Integration:** Full logging and monitoring

## 🔧 Configuration

### Lambda Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | RDS endpoint | `database-1.c3easrmf.ap-south-1.rds.amazonaws.com` |
| `DB_NAME` | Database name | `postgres` |
| `DB_PORT` | Database port | `5432` |
| `DB_USER` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `Dashboard6287` |
| `TABLE_NAME` | Target table name | `audittrail_firehose` |

### RDS Configuration

- **Endpoint:** `database-1.c3easrmf.ap-south-1.rds.amazonaws.com`
- **Database:** `postgres`
- **User:** `postgres`
- **Password:** `Dashboard6287`
- **Port:** `5432`

## 📊 Data Type Mapping

| Parquet/Arrow Type | PostgreSQL Type |
|-------------------|-----------------|
| `int32` | `INTEGER` |
| `int64` | `BIGINT` |
| `float64` | `DOUBLE PRECISION` |
| `string` / `utf8` | `TEXT` |
| `bool` | `BOOLEAN` |
| `timestamp[ns]` | `TIMESTAMP` |
| `date32` | `DATE` |

See `lambda_function.py` for complete mapping.

## 🧪 Testing

### Test Locally

```bash
# Analyze schema
python analyze_parquet_schema.py

# Load to local PostgreSQL
python load_parquet_to_postgres.py
```

### Test Lambda Function

1. **Upload test file to S3:**
   ```bash
   aws s3 cp test.parquet s3://YOUR-BUCKET-NAME/
   ```

2. **Invoke manually:**
   ```bash
   aws lambda invoke \
       --function-name parquet-to-postgres-processor \
       --payload file://test-event.json \
       response.json
   ```

3. **Check CloudWatch logs:**
   ```bash
   aws logs tail /aws/lambda/parquet-to-postgres-processor --follow
   ```

## 📝 Deployment Scripts

### Linux/Mac
```bash
chmod +x deploy.sh
./deploy.sh [function-name] [bucket-name]
```

### Windows
```powershell
.\deploy.ps1 [function-name] [bucket-name]
```

## 🔒 Security Best Practices

1. **Use AWS Secrets Manager** for database credentials (see DEPLOYMENT_GUIDE.md)
2. **Enable VPC** for Lambda if RDS is in private subnet
3. **Use IAM roles** instead of hardcoded credentials
4. **Enable encryption** for S3 and RDS
5. **Regularly rotate** database passwords

## 📈 Monitoring

- **CloudWatch Logs:** `/aws/lambda/parquet-to-postgres-processor`
- **CloudWatch Metrics:** Invocations, Duration, Errors, Throttles
- **Set up alarms** for errors and timeouts

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Timeout | Increase Lambda timeout (max 15 min) |
| Memory Error | Increase Lambda memory (recommended: 3008 MB) |
| RDS Connection Failed | Check security group allows Lambda |
| Package Too Large | Use Lambda Layers for pyarrow/pandas |
| S3 Access Denied | Verify IAM role permissions |

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete step-by-step deployment guide
- **[QUICK_START.md](QUICK_START.md)** - Quick reference checklist
- **[test-event.json](test-event.json)** - Sample S3 event for testing

## 🛠️ Requirements

### Local Development
- Python 3.9+
- PostgreSQL (local or RDS)
- AWS CLI (for deployment)

### Lambda Runtime
- Python 3.9, 3.10, or 3.11
- Memory: 3008 MB (recommended)
- Timeout: 900 seconds (15 minutes)
- Ephemeral Storage: 10240 MB (10 GB)

## 📦 Dependencies

### Local
- `pyarrow>=10.0.0`
- `pandas>=1.5.0`
- `psycopg2-binary>=2.9.0`

### Lambda
- `pyarrow==14.0.1`
- `pandas==2.1.4`
- `psycopg2-binary==2.9.9`
- `boto3==1.34.0` (pre-installed in Lambda)

## 🤝 Contributing

1. Test locally before deploying
2. Update documentation for any changes
3. Follow AWS Lambda best practices
4. Add error handling for edge cases

## 📄 License

This project is provided as-is for internal use.

## 🆘 Support

For issues:
1. Check CloudWatch logs
2. Review Lambda function metrics
3. Verify IAM permissions
4. Test database connectivity separately
5. See DEPLOYMENT_GUIDE.md for detailed troubleshooting

---

**Created by:** AWS Solution Architect & Full Stack Python Developer  
**Last Updated:** 2024

