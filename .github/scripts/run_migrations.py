#!/usr/bin/env python3

import os
import sys
import glob
import logging
import mysql.connector
from datetime import datetime
from typing import List, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DatabaseMigrator:
    def __init__(self):
        self.conn = mysql.connector.connect(
            host=os.getenv('DB_HOST'),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            database=os.getenv('DB_NAME')
        )
        self.cursor = self.conn.cursor()
        self.ensure_migration_table()

    def ensure_migration_table(self):
        """Ensure the schema_migrations table exists."""
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id INT AUTO_INCREMENT PRIMARY KEY,
                schema_version INT NOT NULL,
                migration_name VARCHAR(255) NOT NULL,
                last_migration_date DATETIME NOT NULL,
                status ENUM('success', 'failed', 'rolled_back') NOT NULL,
                error_message TEXT
            )
        """)
        self.conn.commit()

    def get_current_version(self) -> int:
        """Get the current schema version."""
        self.cursor.execute("""
            SELECT schema_version 
            FROM schema_migrations 
            ORDER BY schema_version DESC 
            LIMIT 1
        """)
        result = self.cursor.fetchone()
        return result[0] if result else 0

    def find_migrations(self) -> List[Tuple[int, str]]:
        """Find all migration files and sort them by version."""
        migrations = []
        
        # Search in all migration directories
        migration_paths = [
            'data/migrations/*.sql',
            'data-canary/migrations/*.sql',
            'data-otservbr-global/migrations/*.sql'
        ]
        
        for path in migration_paths:
            for file in glob.glob(path):
                try:
                    version = int(os.path.basename(file).split('_')[0])
                    migrations.append((version, file))
                except ValueError:
                    logger.warning(f"Skipping invalid migration filename: {file}")
        
        return sorted(migrations)

    def apply_migration(self, version: int, file_path: str) -> bool:
        """Apply a single migration file."""
        try:
            with open(file_path, 'r') as f:
                sql = f.read()

            # Execute migration in a transaction
            self.cursor.execute("START TRANSACTION")
            
            # Execute the migration SQL
            for statement in sql.split(';'):
                if statement.strip():
                    self.cursor.execute(statement)
            
            # Record successful migration
            self.cursor.execute("""
                INSERT INTO schema_migrations 
                (schema_version, migration_name, last_migration_date, status)
                VALUES (%s, %s, %s, 'success')
            """, (version, os.path.basename(file_path), datetime.now()))
            
            self.cursor.execute("COMMIT")
            logger.info(f"Successfully applied migration {version}")
            return True
            
        except Exception as e:
            self.cursor.execute("ROLLBACK")
            logger.error(f"Failed to apply migration {version}: {str(e)}")
            
            # Record failed migration
            self.cursor.execute("""
                INSERT INTO schema_migrations 
                (schema_version, migration_name, last_migration_date, status, error_message)
                VALUES (%s, %s, %s, 'failed', %s)
            """, (version, os.path.basename(file_path), datetime.now(), str(e)))
            self.conn.commit()
            return False

    def run_migrations(self):
        """Run all pending migrations."""
        current_version = self.get_current_version()
        migrations = self.find_migrations()
        
        for version, file_path in migrations:
            if version > current_version:
                logger.info(f"Applying migration {version} from {file_path}")
                if not self.apply_migration(version, file_path):
                    logger.error(f"Migration {version} failed, stopping migration process")
                    sys.exit(1)

    def __del__(self):
        """Cleanup database connections."""
        if hasattr(self, 'cursor') and self.cursor:
            self.cursor.close()
        if hasattr(self, 'conn') and self.conn:
            self.conn.close()

if __name__ == "__main__":
    try:
        migrator = DatabaseMigrator()
        migrator.run_migrations()
    except Exception as e:
        logger.error(f"Migration failed: {str(e)}")
        sys.exit(1)
    sys.exit(0)