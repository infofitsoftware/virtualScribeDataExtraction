"""
Script to analyze parquet schema, create PostgreSQL table, and load data.
"""

import os
import pyarrow.parquet as pq
import pandas as pd
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from pathlib import Path
from typing import Dict, List, Optional


# PostgreSQL connection configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'postgres',
    'port': 5432,
    'user': 'postgres',
    'password': 'admin'
}

# Table name for the data
TABLE_NAME = 'audittrail_firehose'


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
    print(f"Warning: Unknown type '{arrow_type}', defaulting to TEXT")
    return 'TEXT'


def analyze_parquet_schema(file_path: str) -> Optional[Dict]:
    """
    Analyze parquet file schema.
    
    Args:
        file_path: Path to parquet file
        
    Returns:
        Dictionary with schema information
    """
    try:
        parquet_file = pq.ParquetFile(file_path)
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
        
        return {
            'file_path': file_path,
            'num_rows': metadata.num_rows,
            'columns': columns
        }
    except Exception as e:
        print(f"Error analyzing {file_path}: {e}")
        return None


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
    
    sql = f"""CREATE TABLE IF NOT EXISTS {table_name} (
{',\n'.join(columns)}
);"""
    
    return sql


def create_postgres_table(conn, schema_info: Dict, table_name: str, drop_existing: bool = False):
    """
    Create PostgreSQL table from schema.
    
    Args:
        conn: PostgreSQL connection
        schema_info: Schema information dictionary
        table_name: Name of the table to create
        drop_existing: Whether to drop existing table if it exists
    """
    cursor = conn.cursor()
    
    try:
        if drop_existing:
            print(f"Dropping existing table {table_name} if it exists...")
            cursor.execute(f'DROP TABLE IF EXISTS {table_name};')
            conn.commit()
        
        create_sql = generate_create_table_sql(schema_info, table_name)
        print(f"\nCreating table {table_name}...")
        print("SQL Statement:")
        print("-" * 80)
        print(create_sql)
        print("-" * 80)
        
        cursor.execute(create_sql)
        conn.commit()
        print(f"✓ Table {table_name} created successfully!")
        
    except Exception as e:
        conn.rollback()
        print(f"Error creating table: {e}")
        raise
    finally:
        cursor.close()


def load_parquet_to_postgres(conn, file_path: str, table_name: str, batch_size: int = 1000):
    """
    Load data from parquet file to PostgreSQL table.
    
    Args:
        conn: PostgreSQL connection
        file_path: Path to parquet file
        table_name: Name of the target table
        batch_size: Number of rows to insert per batch
    """
    print(f"\nLoading data from {os.path.basename(file_path)}...")
    
    try:
        # Read parquet file in chunks
        parquet_file = pq.ParquetFile(file_path)
        schema = parquet_file.schema_arrow
        
        # Get column names
        column_names = [field.name for field in schema]
        columns_str = ', '.join([f'"{col}"' for col in column_names])
        
        # Read data in batches
        total_rows = 0
        cursor = conn.cursor()
        
        # Read entire file (or in chunks if very large)
        df = pd.read_parquet(file_path)
        
        # Replace NaN with None for PostgreSQL
        df = df.where(pd.notnull(df), None)
        
        # Prepare insert statement
        placeholders = ', '.join(['%s'] * len(column_names))
        insert_sql = f'INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders})'
        
        # Insert data in batches
        rows_to_insert = []
        for idx, row in df.iterrows():
            rows_to_insert.append(tuple(row))
            
            if len(rows_to_insert) >= batch_size:
                cursor.executemany(insert_sql, rows_to_insert)
                conn.commit()
                total_rows += len(rows_to_insert)
                print(f"  Inserted {total_rows:,} rows...", end='\r')
                rows_to_insert = []
        
        # Insert remaining rows
        if rows_to_insert:
            cursor.executemany(insert_sql, rows_to_insert)
            conn.commit()
            total_rows += len(rows_to_insert)
        
        cursor.close()
        print(f"\n✓ Successfully loaded {total_rows:,} rows from {os.path.basename(file_path)}")
        
    except Exception as e:
        conn.rollback()
        print(f"\n✗ Error loading data: {e}")
        raise


def get_common_schema(parquet_files: List[str]) -> Optional[Dict]:
    """
    Analyze all parquet files and return a unified schema.
    Assumes all files have the same schema structure.
    
    Args:
        parquet_files: List of parquet file paths
        
    Returns:
        Unified schema information
    """
    schemas = []
    for file_path in parquet_files:
        schema_info = analyze_parquet_schema(file_path)
        if schema_info:
            schemas.append(schema_info)
    
    if not schemas:
        return None
    
    # Use the first schema as the base (assuming all have same structure)
    base_schema = schemas[0].copy()
    
    # Verify all schemas have the same columns
    base_columns = {col['name']: col for col in base_schema['columns']}
    for schema in schemas[1:]:
        schema_columns = {col['name']: col for col in schema['columns']}
        if set(base_columns.keys()) != set(schema_columns.keys()):
            print("Warning: Parquet files have different schemas!")
            print(f"  Base schema has {len(base_columns)} columns")
            print(f"  {schema['file_path']} has {len(schema_columns)} columns")
    
    return base_schema


def main():
    """Main function to orchestrate the entire process."""
    print("=" * 80)
    print("Parquet to PostgreSQL Data Loader")
    print("=" * 80)
    
    # Find all parquet files
    current_dir = Path('.')
    parquet_files = sorted(list(current_dir.glob('*.parquet')))
    
    if not parquet_files:
        print("No parquet files found in the current directory.")
        return
    
    print(f"\nFound {len(parquet_files)} parquet file(s):")
    for pf in parquet_files:
        print(f"  - {pf.name}")
    
    # Analyze schema from first file (assuming all have same schema)
    print(f"\n{'='*80}")
    print("Analyzing Schema...")
    print(f"{'='*80}")
    
    schema_info = get_common_schema([str(pf) for pf in parquet_files])
    if not schema_info:
        print("Failed to analyze schema. Exiting.")
        return
    
    print(f"\nSchema Analysis Complete:")
    print(f"  Total columns: {len(schema_info['columns'])}")
    print(f"\nColumn Details:")
    print("-" * 80)
    print(f"{'Column Name':<40} {'Arrow Type':<30} {'PostgreSQL Type':<20}")
    print("-" * 80)
    for col in schema_info['columns']:
        print(f"{col['name']:<40} {col['arrow_type']:<30} {col['pg_type']:<20}")
    
    # Connect to PostgreSQL
    print(f"\n{'='*80}")
    print("Connecting to PostgreSQL...")
    print(f"{'='*80}")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print("✓ Connected to PostgreSQL successfully!")
    except Exception as e:
        print(f"✗ Failed to connect to PostgreSQL: {e}")
        print("\nPlease verify your connection settings:")
        for key, value in DB_CONFIG.items():
            if key == 'password':
                print(f"  {key}: {'*' * len(str(value))}")
            else:
                print(f"  {key}: {value}")
        return
    
    try:
        # Create table
        print(f"\n{'='*80}")
        print("Creating PostgreSQL Table...")
        print(f"{'='*80}")
        create_postgres_table(conn, schema_info, TABLE_NAME, drop_existing=False)
        
        # Load data from all parquet files
        print(f"\n{'='*80}")
        print("Loading Data...")
        print(f"{'='*80}")
        
        total_rows_loaded = 0
        for parquet_file in parquet_files:
            try:
                load_parquet_to_postgres(conn, str(parquet_file), TABLE_NAME)
                # Count rows in the file
                pf = pq.ParquetFile(str(parquet_file))
                total_rows_loaded += pf.metadata.num_rows
            except Exception as e:
                print(f"Failed to load {parquet_file.name}: {e}")
                continue
        
        # Verify data
        print(f"\n{'='*80}")
        print("Verification...")
        print(f"{'='*80}")
        cursor = conn.cursor()
        cursor.execute(f'SELECT COUNT(*) FROM {TABLE_NAME};')
        row_count = cursor.fetchone()[0]
        cursor.close()
        
        print(f"Total rows in table {TABLE_NAME}: {row_count:,}")
        print(f"Expected rows from parquet files: {total_rows_loaded:,}")
        
        if row_count == total_rows_loaded:
            print("✓ Data load verification successful!")
        else:
            print("⚠ Warning: Row count mismatch!")
        
        print(f"\n{'='*80}")
        print("Process Complete!")
        print(f"{'='*80}")
        print(f"\nYou can now query the table '{TABLE_NAME}' in PostgreSQL.")
        print(f"Example: SELECT * FROM {TABLE_NAME} LIMIT 10;")
        
    except Exception as e:
        print(f"\n✗ Error during process: {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()
        print("\n✓ Database connection closed.")


if __name__ == "__main__":
    main()

