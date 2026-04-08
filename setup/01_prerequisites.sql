-- ============================================================================
-- Snowpark Connect for Apache Spark - Prerequisites Setup
-- Run as ACCOUNTADMIN or a role with CREATE WAREHOUSE, CREATE COMPUTE POOL,
-- CREATE INTEGRATION, and CREATE DATABASE privileges.
-- ============================================================================


-- ============================================================================
-- STEP 1: QUERY WAREHOUSE
-- ============================================================================
-- This is where ALL Spark Connect queries execute. When PySpark calls
-- df.groupBy(), df.filter(), spark.sql(), or @udf, the operations compile
-- to SQL and run on THIS warehouse -- not the compute pool.
--
-- LARGE is recommended for TPC-H SF100 (600M rows). Scale up to X-LARGE
-- or larger for production workloads.
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS SPARK_CONNECT_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Query warehouse for Spark Connect SQL pushdown. All PySpark operations execute here.';


-- ============================================================================
-- STEP 2: COMPUTE POOL
-- ============================================================================
-- The compute pool hosts the container that runs the notebook kernel and
-- PySpark client. It is lightweight -- it only compiles query plans and
-- sends them to the warehouse.
--
-- CPU_X64_S (2 vCPU, 8GB RAM) is sufficient. The heavy compute happens
-- on the warehouse, not here.
-- ============================================================================

CREATE COMPUTE POOL IF NOT EXISTS SPARK_CONNECT_POOL
    MIN_NODES = 1
    MAX_NODES = 1
    INSTANCE_FAMILY = CPU_X64_S
    AUTO_RESUME = TRUE
    AUTO_SUSPEND_SECS = 3600
    COMMENT = 'Hosts the PySpark client container. Lightweight -- queries push to warehouse.';

DESCRIBE COMPUTE POOL SPARK_CONNECT_POOL;


-- ============================================================================
-- STEP 3: PYPI EXTERNAL ACCESS INTEGRATION
-- ============================================================================
-- Required so the container can pip install snowpark-connect[jdk] at runtime.
-- This creates a network rule allowing outbound HTTPS to PyPI, then wraps it
-- in an External Access Integration.
--
-- If you already have a PyPI EAI (e.g., PYPI_ACCESS_INTEGRATION), skip this
-- and use your existing one when configuring the service.
-- ============================================================================

CREATE NETWORK RULE IF NOT EXISTS SPARK_CONNECT_PYPI_NETWORK_RULE
    TYPE = HOST_PORT
    MODE = EGRESS
    VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org', 'files.pythonhosted.org');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION SPARK_CONNECT_PYPI_EAI
    ALLOWED_NETWORK_RULES = (SPARK_CONNECT_PYPI_NETWORK_RULE)
    ENABLED = TRUE
    COMMENT = 'Allows pip install from PyPI inside notebook containers.';


-- ============================================================================
-- STEP 4: DATABASE AND SCHEMA
-- ============================================================================
-- The notebook writes output tables (e.g., CLASSIFIED_COMMENTS) here.
-- Adjust to your preferred database/schema.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS DEMO_DB;
CREATE SCHEMA IF NOT EXISTS DEMO_DB.PUBLIC;

USE DATABASE DEMO_DB;
USE SCHEMA PUBLIC;


-- ============================================================================
-- STEP 5: VERIFY DATASET ACCESS
-- ============================================================================
-- The demo uses TPC-H SF100 from SNOWFLAKE_SAMPLE_DATA (included with every
-- Snowflake account). Verify you can query it.
-- ============================================================================

SELECT COUNT(*) AS row_count
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF100.LINEITEM;

SELECT L_ORDERKEY, L_COMMENT, L_SHIPMODE, L_SHIPDATE, L_EXTENDEDPRICE
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF100.LINEITEM
WHERE L_COMMENT IS NOT NULL
LIMIT 5;


-- ============================================================================
-- STEP 6: CREATE SERVICE (Container Runtime) -- DONE IN SNOWSIGHT UI
-- ============================================================================
--
-- Services for Notebooks in Workspaces are configured through the Snowsight UI,
-- not SQL. Follow these steps:
--
-- 1. Navigate to: Projects > Notebooks > Open any notebook
-- 2. Click the gear icon (Settings) in the top-right
-- 3. Under "Connected service", click "Create service" or select existing
-- 4. Configure the service:
--
--    Service name:     SPARK_CONNECT_SERVICE (or your preferred name)
--    Compute pool:     SPARK_CONNECT_POOL (created in Step 2)
--    Runtime:          v2.2
--    Language:         CPU | Python 3.11  (DO NOT use Python 3.12 -- jdk4py needs distutils)
--    Idle timeout:     24 hours (recommended for demos)
--    Enabled EAIs:     SPARK_CONNECT_PYPI_EAI (or your existing PYPI_ACCESS_INTEGRATION)
--
-- 5. IMPORTANT: Set the "Query Warehouse" dropdown to SPARK_CONNECT_WH
--    This is SEPARATE from the compute pool. The warehouse is where all
--    PySpark operations (groupBy, filter, agg, UDFs) actually execute.
--
-- ============================================================================


-- ============================================================================
-- GRANT PRIVILEGES (if needed for non-ACCOUNTADMIN roles)
-- ============================================================================
-- Uncomment and adjust role name as needed:
--
-- GRANT USAGE ON WAREHOUSE SPARK_CONNECT_WH TO ROLE <your_role>;
-- GRANT USAGE ON COMPUTE POOL SPARK_CONNECT_POOL TO ROLE <your_role>;
-- GRANT USAGE ON DATABASE DEMO_DB TO ROLE <your_role>;
-- GRANT USAGE ON SCHEMA DEMO_DB.PUBLIC TO ROLE <your_role>;
-- GRANT CREATE TABLE ON SCHEMA DEMO_DB.PUBLIC TO ROLE <your_role>;
-- GRANT CREATE FUNCTION ON SCHEMA DEMO_DB.PUBLIC TO ROLE <your_role>;
-- GRANT USAGE ON INTEGRATION SPARK_CONNECT_PYPI_EAI TO ROLE <your_role>;
