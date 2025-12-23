"""
Script to analyze and describe the schema of parquet files in the current directory.
"""

import os
import pyarrow.parquet as pq
import pandas as pd
from pathlib import Path


def describe_schema(file_path):
    """
    Analyze and describe the schema of a parquet file.
    
    Args:
        file_path: Path to the parquet file
        
    Returns:
        Dictionary containing schema information
    """
    print(f"\n{'='*80}")
    print(f"Analyzing: {file_path}")
    print(f"{'='*80}\n")
    
    try:
        # Read parquet file using pyarrow for detailed schema info
        parquet_file = pq.ParquetFile(file_path)
        # Get Arrow schema (not Parquet schema) for proper field access
        schema = parquet_file.schema_arrow
        
        # Get metadata
        metadata = parquet_file.metadata
        num_rows = metadata.num_rows
        num_row_groups = metadata.num_row_groups
        
        print(f"File: {os.path.basename(file_path)}")
        print(f"Number of rows: {num_rows:,}")
        print(f"Number of row groups: {num_row_groups}")
        print(f"\nSchema ({len(schema)} columns):")
        print("-" * 80)
        
        # Display column information
        for i, field in enumerate(schema, 1):
            field_name = field.name
            field_type = str(field.type)
            nullable = field.nullable
            
            # Get additional info from metadata if available
            print(f"{i:2d}. Column: {field_name}")
            print(f"    Type: {field_type}")
            print(f"    Nullable: {nullable}")
            
            # Try to get sample data to show examples
            try:
                df = pd.read_parquet(file_path, columns=[field_name])
                if len(df) > 0:
                    sample_value = df[field_name].iloc[0]
                    unique_count = df[field_name].nunique()
                    null_count = df[field_name].isna().sum()
                    print(f"    Sample value: {sample_value}")
                    print(f"    Unique values: {unique_count:,}")
                    print(f"    Null values: {null_count:,}")
            except Exception as e:
                print(f"    (Could not read sample data: {e})")
            
            print()
        
        # Display schema as a table
        print("\nSchema Summary Table:")
        print("-" * 80)
        print(f"{'Column Name':<40} {'Type':<25} {'Nullable':<10}")
        print("-" * 80)
        for field in schema:
            print(f"{field.name:<40} {str(field.type):<25} {str(field.nullable):<10}")
        
        # Try to read a small sample with pandas for additional insights
        print("\n\nData Sample (first 5 rows):")
        print("-" * 80)
        try:
            df_sample = pd.read_parquet(file_path, nrows=5)
            print(df_sample.to_string())
        except Exception as e:
            print(f"Could not read sample data: {e}")
        
        return {
            'file_path': file_path,
            'num_rows': num_rows,
            'num_row_groups': num_row_groups,
            'schema': schema,
            'columns': [{'name': field.name, 'type': str(field.type), 'nullable': field.nullable} 
                       for field in schema]
        }
        
    except Exception as e:
        print(f"Error reading file {file_path}: {e}")
        return None


def main():
    """Main function to analyze all parquet files in the current directory."""
    current_dir = Path('.')
    
    # Find all parquet files
    parquet_files = list(current_dir.glob('*.parquet'))
    
    if not parquet_files:
        print("No parquet files found in the current directory.")
        return
    
    print(f"Found {len(parquet_files)} parquet file(s) to analyze.\n")
    
    results = []
    for parquet_file in sorted(parquet_files):
        result = describe_schema(str(parquet_file))
        if result:
            results.append(result)
    
    # Summary comparison
    if len(results) > 1:
        print(f"\n\n{'='*80}")
        print("SCHEMA COMPARISON SUMMARY")
        print(f"{'='*80}\n")
        
        # Compare schemas
        all_columns = set()
        for result in results:
            all_columns.update([col['name'] for col in result['columns']])
        
        print(f"Total unique columns across all files: {len(all_columns)}")
        print("\nColumn presence across files:")
        print("-" * 80)
        print(f"{'Column Name':<40} ", end="")
        for result in results:
            print(f"{os.path.basename(result['file_path']):<30} ", end="")
        print()
        print("-" * 80)
        
        for col_name in sorted(all_columns):
            print(f"{col_name:<40} ", end="")
            for result in results:
                col_names = [col['name'] for col in result['columns']]
                if col_name in col_names:
                    col_info = next(col for col in result['columns'] if col['name'] == col_name)
                    print(f"{col_info['type']:<30} ", end="")
                else:
                    print(f"{'N/A':<30} ", end="")
            print()


if __name__ == "__main__":
    main()

