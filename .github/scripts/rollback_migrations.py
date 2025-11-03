#!/usr/bin/env python3

import os
import sys
import glob
import logging
import argparse
import mysql.connector
from datetime import datetime, timedelta
from typing import List, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DatabaseRollback:
    def __init__(self):
        self.conn = mysql.connector.connect(
            host=os.getenv('DB_HOST'),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            database=os.getenv('DB_NAME')
        )
        self.cursor = self.conn.cursor()

    def get_migrations_to_rollback(self, target_version: int = None, hours: int = None) -> List[Tuple[int, str]]:
        """Get list of migrations to roll back."""
        if target_version is not None:
            query = """
                SELECT schema_version, migration_name 
                FROM schema_migrations 
                WHERE schema_version > %s 
                AND status = 'success'
                ORDER BY schema_version DESC
            """
            self.cursor.execute(query, (target_version,))
        elif hours is not None:
            cutoff_time = datetime.now() - timedelta(hours=hours)
            query = """
                SELECT schema_version, migration_name 
                FROM schema_migrations 
                WHERE last_migration_date > %s 
                AND status = 'success'
                ORDER BY schema_version DESC
            """
            self.cursor.execute(query, (cutoff_time,))
        else:
            # Default to rolling back the last migration
            query = """
                SELECT schema_version, migration_name 
                FROM schema_migrations 
                WHERE status = 'success'
                ORDER BY schema_version DESC
                LIMIT 1
            """
            self.cursor.execute(query)
            
        return self.cursor.fetchall()

    def find_rollback_file(self, migration_name: str) -> str:
        """Find the corresponding rollback file for a migration."""
        # Remove extension and add .down.sql
        base_name = os.path.splitext(migration_name)[0]
        rollback_name = f"{base_name}.down.sql"
        
        # Search in all migration directories
        migration_paths = [
            'data/migrations',
            'data-canary/migrations',
            'data-otservbr-global/migrations'
        ]
        
        for path in migration_paths:
            rollback_path = os.path.join(path, rollback_name)
            if os.path.exists(rollback_path):
                return rollback_path
                
        raise FileNotFoundError(f"Rollback file not found for {migration_name}")

    def apply_rollback(self, version: int, migration_name: str) -> bool:
        """Apply a single rollback file."""
        try:
            rollback_file = self.find_rollback_file(migration_name)
            
            with open(rollback_file, 'r') as f:
                sql = f.read()

            # Execute rollback in a transaction
            self.cursor.execute("START TRANSACTION")
            
            # Execute the rollback SQL
            for statement in sql.split(';'):
                if statement.strip():
                    self.cursor.execute(statement)
            
            # Update migration status
            self.cursor.execute("""
                UPDATE schema_migrations 
                SET status = 'rolled_back',
                    last_migration_date = %s
                WHERE schema_version = %s
            """, (datetime.now(), version))
            
            self.cursor.execute("COMMIT")
            logger.info(f"Successfully rolled back migration {version}")
            return True
            
        except Exception as e:
            self.cursor.execute("ROLLBACK")
            logger.error(f"Failed to roll back migration {version}: {str(e)}")
            return False

    def run_rollback(self, target_version: int = None, hours: int = None):
        """Run rollback process."""
        migrations = self.get_migrations_to_rollback(target_version, hours)
        
        for version, migration_name in migrations:
            logger.info(f"Rolling back migration {version} ({migration_name})")
            if not self.apply_rollback(version, migration_name):
                logger.error(f"Rollback of migration {version} failed, stopping rollback process")
                sys.exit(1)

    def __del__(self):
        """Cleanup database connections."""
        if hasattr(self, 'cursor') and self.cursor:
            self.cursor.close()
        if hasattr(self, 'conn') and self.conn:
            self.conn.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Database rollback tool')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--to-version', type=int, help='Roll back to specific version')
    group.add_argument('--hours', type=int, help='Roll back migrations from last N hours')
    
    args = parser.parse_args()
    
    try:
        rollback = DatabaseRollback()
        rollback.run_rollback(args.to_version, args.hours)
    except Exception as e:
        logger.error(f"Rollback failed: {str(e)}")
        sys.exit(1)
    sys.exit(0)