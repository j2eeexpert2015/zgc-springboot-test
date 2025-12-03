-- Initialize the zgctest database
-- This script runs automatically when the container starts

-- Create extension for better random functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- The items table will be created by Hibernate, but we can add indexes here
-- CREATE INDEX IF NOT EXISTS idx_items_price ON items(price);

-- Grant all privileges to the zgcuser
GRANT ALL PRIVILEGES ON DATABASE zgctest TO zgcuser;
