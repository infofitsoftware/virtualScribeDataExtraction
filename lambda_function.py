"""
AWS Lambda function to process parquet files from S3 and load into RDS PostgreSQL.
Triggered by S3 PUT events.
"""

import json
import os
import boto3
import pyarrow.parquet as pq
import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from io import BytesIO
from typing import Dict, Optional
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# RDS PostgreSQL connection configuration from environment variables
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'database-1.c3easrmf.ap-south-1.rds.amazonaws.com'),
    'database': os.environ.get('DB_NAME', 'postgres'),
    'port': int(os.environ.get('DB_PORT', '5432')),
    'user': os.environ.get('DB_USER', 'postgres'),
    'password': os.environ.get('DB_PASSWORD', 'Dashboard6287')
}

# Table name from environment variable or default
TABLE_NAME = os.environ.get('TABLE_NAME', 'audittrail_firehose')

# Initialize S3 client
s3_client = boto3.client('s3')


def map_arrow_to_postgres_type(arrow_type: str) -> str:
    """
    Map Arrow/Parquet data types to PostgreSQL data types.
    
    Args:
        arrow_type: Arrow type as string
        
    Returns:
        PostgreSQL type as string
    """
    type_mapping = {
        # Integer types
        'int8': 'BIGINT',
        'int16': 'SMALLINT',
        'int32': 'INTEGER',
        'int64': 'BIGINT',
        'uint8': 'SMALLINT',
        'uint16': 'INTEGER',
        'uint32': 'BIGINT',
        'uint64': 'NUMERIC(20)',
        
        # Floating point types
        'float': 'REAL',
        'float32': 'REAL',
        'float64': 'DOUBLE PRECISION',
        'double': 'DOUBLE PRECISION',
        
        # String types
        'string': 'TEXT',
        'utf8': 'TEXT',
        'large_string': 'TEXT',
        'binary': 'BYTEA',
        'large_binary': 'BYTEA',
        
        # Boolean
        'bool': 'BOOLEAN',
        'boolean': 'BOOLEAN',
        
        # Date/Time types
        'date32': 'DATE',
        'date64': 'DATE',
        'timestamp': 'TIMESTAMP',
        'timestamp[ns]': 'TIMESTAMP',
        'timestamp[us]': 'TIMESTAMP',
        'timestamp[ms]': 'TIMESTAMP',
        'timestamp[s]': 'TIMESTAMP',
        'time32': 'TIME',
        'time64': 'TIME',
        
        # Decimal
        'decimal128': 'NUMERIC',
        'decimal256': 'NUMERIC',
    }
    
    # Handle nested types (e.g., timestamp[ns])
    arrow_type_lower = str(arrow_type).lower()
    
    # Check for exact matches first
    if arrow_type_lower in type_mapping:
        return type_mapping[arrow_type_lower]
    
    # Check for partial matches (e.g., timestamp[ns])
    for key, value in type_mapping.items():
        if key in arrow_type_lower:
            return value
    
    # Default to TEXT for unknown types
    logger.warning(f"Unknown type '{arrow_type}', defaulting to TEXT")
    return 'TEXT'


def analyze_parquet_schema_from_s3(bucket: str, key: str) -> Optional[Dict]:
    """
    Analyze parquet file schema from S3.
    
    Args:
        bucket: S3 bucket name
        key: S3 object key
        
    Returns:
        Dictionary with schema information
    """
    try:
        # Download parquet file from S3
        logger.info(f"Downloading parquet file from s3://{bucket}/{key}")
        response = s3_client.get_object(Bucket=bucket, Key=key)
        parquet_data = response['Body'].read()
        
        # Read parquet file from memory
        parquet_file = pq.ParquetFile(BytesIO(parquet_data))
        schema = parquet_file.schema_arrow
        metadata = parquet_file.metadata
        
        columns = []
        for field in schema:
            pg_type = map_arrow_to_postgres_type(str(field.type))
            columns.append({
                'name': field.name,
                'arrow_type': str(field.type),
                'pg_type': pg_type,
                'nullable': field.nullable
            })
        
        logger.info(f"Schema analyzed: {len(columns)} columns, {metadata.num_rows} rows")
        
        return {
            'file_path': f"s3://{bucket}/{key}",
            'num_rows': metadata.num_rows,
            'columns': columns
        }
    except Exception as e:
        logger.error(f"Error analyzing schema from S3: {e}")
        raise


def generate_create_table_sql(schema_info: Dict, table_name: str) -> str:
    """
    Generate CREATE TABLE SQL statement from schema.
    
    Args:
        schema_info: Schema information dictionary
        table_name: Name of the table to create
        
    Returns:
        CREATE TABLE SQL statement
    """
    columns = []
    for col in schema_info['columns']:
        col_def = f'    "{col["name"]}" {col["pg_type"]}'
        if not col['nullable']:
            col_def += ' NOT NULL'
        columns.append(col_def)
    
    # Join columns with newline (can't use \n in f-string expression)
    columns_str = ',\n'.join(columns)
    sql = f"""CREATE TABLE IF NOT EXISTS {table_name} (
{columns_str}
);"""
    
    return sql


def ensure_table_exists(conn, schema_info: Dict, table_name: str):
    """
    Ensure PostgreSQL table exists, create if it doesn't.
    
    Args:
        conn: PostgreSQL connection
        schema_info: Schema information dictionary
        table_name: Name of the table
    """
    cursor = conn.cursor()
    
    try:
        # Check if table exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = %s
            );
        """, (table_name,))
        
        table_exists = cursor.fetchone()[0]
        
        if not table_exists:
            logger.info(f"Table {table_name} does not exist. Creating...")
            create_sql = generate_create_table_sql(schema_info, table_name)
            cursor.execute(create_sql)
            conn.commit()
            logger.info(f"Table {table_name} created successfully")
        else:
            logger.info(f"Table {table_name} already exists")
            
    except Exception as e:
        conn.rollback()
        logger.error(f"Error ensuring table exists: {e}")
        raise
    finally:
        cursor.close()


def load_parquet_from_s3_to_postgres(conn, bucket: str, key: str, table_name: str):
    """
    Load data from S3 parquet file to PostgreSQL table.
    
    Args:
        conn: PostgreSQL connection
        bucket: S3 bucket name
        key: S3 object key
        table_name: Name of the target table
    """
    logger.info(f"Loading data from s3://{bucket}/{key} to table {table_name}")
    
    try:
        # Download parquet file from S3
        logger.info(f"Downloading parquet file from S3...")
        response = s3_client.get_object(Bucket=bucket, Key=key)
        parquet_data = response['Body'].read()
        
        # Read parquet file into pandas DataFrame
        logger.info("Reading parquet file into DataFrame...")
        df = pd.read_parquet(BytesIO(parquet_data))
        
        logger.info(f"DataFrame shape: {df.shape}")
        
        # Replace NaN with None for PostgreSQL
        df = df.where(pd.notnull(df), None)
        
        # Get column names
        column_names = list(df.columns)
        columns_str = ', '.join([f'"{col}"' for col in column_names])
        
        # Prepare insert statement
        placeholders = ', '.join(['%s'] * len(column_names))
        insert_sql = f'INSERT INTO {table_name} ({columns_str}) VALUES %s'
        
        # Convert DataFrame to list of tuples
        values = [tuple(row) for row in df.values]
        
        # Insert data using execute_values for better performance
        cursor = conn.cursor()
        logger.info(f"Inserting {len(values)} rows...")
        
        execute_values(
            cursor,
            insert_sql,
            values,
            template=None,
            page_size=1000
        )
        
        conn.commit()
        cursor.close()
        
        logger.info(f"✓ Successfully loaded {len(values):,} rows from {key}")
        
    except Exception as e:
        conn.rollback()
        logger.error(f"✗ Error loading data: {e}")
        raise


def lambda_handler(event, context):
    """
    AWS Lambda handler function.
    
    Args:
        event: S3 event containing bucket and object information
        context: Lambda context object
        
    Returns:
        Response dictionary
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Process each S3 record in the event
        for record in event.get('Records', []):
            # Extract S3 information
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Skip if not a parquet file
            if not key.lower().endswith('.parquet'):
                logger.info(f"Skipping non-parquet file: {key}")
                continue
            
            logger.info(f"Processing parquet file: s3://{bucket}/{key}")
            
            # Analyze schema
            schema_info = analyze_parquet_schema_from_s3(bucket, key)
            if not schema_info:
                logger.error(f"Failed to analyze schema for {key}")
                continue
            
            # Connect to RDS PostgreSQL
            logger.info("Connecting to RDS PostgreSQL...")
            try:
                conn = psycopg2.connect(**DB_CONFIG)
                logger.info("✓ Connected to PostgreSQL successfully!")
            except Exception as e:
                logger.error(f"✗ Failed to connect to PostgreSQL: {e}")
                raise
            
            try:
                # Ensure table exists
                ensure_table_exists(conn, schema_info, TABLE_NAME)
                
                # Load data
                load_parquet_from_s3_to_postgres(conn, bucket, key, TABLE_NAME)
                
                logger.info(f"✓ Successfully processed {key}")
                
            except Exception as e:
                logger.error(f"Error processing {key}: {e}")
                raise
            finally:
                conn.close()
                logger.info("Database connection closed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully processed parquet file(s)',
                'processed_files': [record['s3']['object']['key'] for record in event.get('Records', [])]
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to process parquet file(s)'
            })
        }

