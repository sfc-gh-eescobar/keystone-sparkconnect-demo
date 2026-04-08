-- ============================================================================
-- Optional: Git Integration Setup
-- ============================================================================
-- Set up a Git repository integration in Snowflake so you can create a
-- Workspace directly from this GitHub repo. This lets you skip manual
-- file uploads -- the notebook and setup files are pulled from Git.
-- ============================================================================


-- ============================================================================
-- STEP 1: CREATE API INTEGRATION FOR GITHUB
-- ============================================================================
-- If you already have a GitHub API integration, skip this step and use
-- your existing one in Step 2.
-- ============================================================================

CREATE OR REPLACE API INTEGRATION SPARK_CONNECT_GIT_INTEGRATION
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-eescobar/')
    ENABLED = TRUE
    COMMENT = 'Git integration for Spark Connect demo repository.';


-- ============================================================================
-- STEP 2: CREATE GIT REPOSITORY
-- ============================================================================
-- This creates a Snowflake object that mirrors the GitHub repo.
-- ============================================================================

CREATE OR REPLACE GIT REPOSITORY DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO
    API_INTEGRATION = SPARK_CONNECT_GIT_INTEGRATION
    ORIGIN = 'https://github.com/sfc-gh-eescobar/keystone-sparkconnect-demo';


-- ============================================================================
-- STEP 3: FETCH LATEST CONTENT
-- ============================================================================

ALTER GIT REPOSITORY DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO FETCH;


-- ============================================================================
-- STEP 4: VERIFY CONTENTS
-- ============================================================================

SHOW GIT BRANCHES IN DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO;

LS @DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO/branches/main/;


-- ============================================================================
-- HOW TO CREATE A WORKSPACE FROM THIS REPO
-- ============================================================================
--
-- 1. In Snowsight, go to: Projects > Workspaces
-- 2. Click "+ Workspace" > "Create from Git Repository"
-- 3. Select repository: DEMO_DB.PUBLIC.SPARK_CONNECT_DEMO_REPO
-- 4. Branch: main
-- 5. This creates a workspace with all files from the repo
-- 6. Open the notebook at: notebook/keystone_spark_connect_text_processing.ipynb
-- 7. Configure the service as described in 01_prerequisites.sql (Step 6)
-- 8. Set Query Warehouse to SPARK_CONNECT_WH
--
-- ============================================================================
