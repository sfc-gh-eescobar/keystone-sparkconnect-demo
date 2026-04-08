-- ============================================================================
-- Cleanup Script
-- Run this to tear down all resources created for the Spark Connect demo.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Drop output tables created by the notebook
DROP TABLE IF EXISTS DEMO_DB.PUBLIC.CLASSIFIED_COMMENTS;

-- Drop Snowflake UDF created by the notebook
DROP FUNCTION IF EXISTS DEMO_DB.PUBLIC.TEXT_SIMILARITY_SCORE(STRING, STRING);

-- Drop the query warehouse
DROP WAREHOUSE IF EXISTS SPARK_CONNECT_WH;

-- Stop and drop the compute pool
ALTER COMPUTE POOL IF EXISTS SPARK_CONNECT_POOL STOP ALL;
DROP COMPUTE POOL IF EXISTS SPARK_CONNECT_POOL;

-- Drop external access integration and network rule
DROP INTEGRATION IF EXISTS SPARK_CONNECT_PYPI_EAI;
DROP NETWORK RULE IF EXISTS SPARK_CONNECT_PYPI_NETWORK_RULE;

-- Optional: Drop Git integration resources
-- DROP GIT REPOSITORY IF EXISTS DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO;
-- DROP INTEGRATION IF EXISTS SPARK_CONNECT_GIT_INTEGRATION;

-- Optional: Drop demo database (WARNING: drops all objects in the database)
-- DROP DATABASE IF EXISTS DEMO_DB;
