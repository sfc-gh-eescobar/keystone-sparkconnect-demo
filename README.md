# Snowpark Connect for Apache Spark -- Running Spark Workloads on Snowflake

Run your existing PySpark code on Snowflake warehouses instead of a Spark cluster. No data movement, no cluster management, same PySpark API.

This notebook processes **600 million rows** from TPC-H using standard PySpark operations (DataFrame API, SQL, UDFs, window functions) -- all executed on Snowflake compute.

## Architecture

Snowpark Connect uses **two compute layers** in Snowflake Notebooks (Workspaces):

```
+---------------------------+          +---------------------------+
|   COMPUTE POOL (Service)  |          |   QUERY WAREHOUSE         |
|   CPU_X64_S               |          |   SPARK_CONNECT_WH (L)    |
|                           |          |                           |
|   - Hosts container       |  pushes  |   - Executes all queries  |
|   - Runs Python/PySpark   |  SQL to  |   - groupBy, agg, filter  |
|   - Compiles query plans  | -------> |   - Text search, joins    |
|   - ~2 vCPU, 8GB RAM      |          |   - UDF execution         |
|   - pip install packages  |          |   - Auto-scales           |
+---------------------------+          +---------------------------+
     Container Runtime                    Query Execution Engine
     (configured on Service)             (set in Notebook UI)
```

**Compute Pool** = where the container runs (PySpark client, Python kernel). Lightweight -- just sends query plans.

**Query Warehouse** = where Snowflake executes the SQL that Spark Connect generates. This is where the real compute happens.

## Prerequisites

- Snowflake account with **Notebooks in Workspaces** enabled
- `ACCOUNTADMIN` role (or equivalent privileges to create warehouses, compute pools, and integrations)
- Access to `SNOWFLAKE_SAMPLE_DATA.TPCH_SF100` (included with every Snowflake account)

## Quick Start

### Option A: Git Integration (Recommended)

Create a workspace directly from this GitHub repo -- no file downloads needed.

1. Run `setup/01_prerequisites.sql` to create the warehouse, compute pool, and PyPI EAI
2. Run `setup/02_git_integration.sql` to set up the Git repository in Snowflake
3. In Snowsight, go to **Projects > Workspaces**, create a new workspace from the Git repository (see instructions in `02_git_integration.sql`)
4. Open the notebook in the workspace, configure the service and set the query warehouse (see [Service Setup](#service-setup) below)

### Option B: Manual Upload

1. Run `setup/01_prerequisites.sql` to create the warehouse, compute pool, and PyPI EAI
2. Download `notebook/keystone_spark_connect_text_processing.ipynb`
3. In Snowsight, go to **Projects > Workspaces**, open or create a workspace, and upload the `.ipynb` file
4. Open the notebook in the workspace, configure the service and set the query warehouse (see [Service Setup](#service-setup) below)

## Infrastructure Setup

Run `setup/01_prerequisites.sql` in a SQL worksheet. It creates:

| Resource | Name | Purpose |
|----------|------|---------|
| **Warehouse** | `SPARK_CONNECT_WH` (Large) | Executes all PySpark operations (SQL pushdown) |
| **Compute Pool** | `SPARK_CONNECT_POOL` (CPU_X64_S) | Hosts the container with PySpark client |
| **Network Rule** | `SPARK_CONNECT_PYPI_NETWORK_RULE` | Allows outbound HTTPS to PyPI |
| **EAI** | `SPARK_CONNECT_PYPI_EAI` | External Access Integration for pip install |
| **Database** | `DEMO_DB.PUBLIC` | Schema for output tables |

### Why CPU_X64_S for the compute pool?

The PySpark client is lightweight -- it only compiles query plans and sends them to the warehouse. The container does not process data. `CPU_X64_S` (2 vCPU, 8GB RAM) is sufficient.

### Why Large for the warehouse?

The warehouse executes all SQL pushdown from Spark Connect -- aggregations, text search, UDFs across 600M rows. Large provides good demo performance. Scale up to X-Large for faster results.

## Service Setup

Services for Notebooks in Workspaces are configured through the **Snowsight UI**:

1. In Snowsight, go to **Projects > Workspaces** and open your workspace
2. Open the notebook file, then click the **gear icon** (Settings) in the top-right
3. Under **"Connected service"**, create or select a service with:

| Setting | Value |
|---------|-------|
| Compute pool | `SPARK_CONNECT_POOL` (or `SYSTEM_COMPUTE_POOL_CPU`) |
| Runtime | v2.2 |
| Language | CPU \| Python 3.11 |
| Idle timeout | 24 hours (recommended for demos) |
| Enabled EAIs | `SPARK_CONNECT_PYPI_EAI` (or your existing `PYPI_ACCESS_INTEGRATION`) |

4. **Set the Query Warehouse** to `SPARK_CONNECT_WH`
   - This is a **separate dropdown** from the compute pool
   - This is where all PySpark operations actually execute

> **Important:** Do NOT use Python 3.12. The `jdk4py` package (bundled with `snowpark-connect[jdk]`) requires `distutils`, which was removed in Python 3.12.

## PyPI External Access

The notebook runs `!pip install snowpark-connect[jdk]` in the first cell. This requires **PyPI External Access** enabled on the service.

`snowpark-connect[jdk]` bundles:
- `snowpark-connect` -- the Spark Connect client for Snowflake
- `jdk4py` -- a portable Java runtime (JVM is required by Spark but not pre-installed in the container)

If pip install fails with a connection error, verify that:
1. The EAI (`SPARK_CONNECT_PYPI_EAI` or `PYPI_ACCESS_INTEGRATION`) is enabled on your service
2. The network rule includes: `pypi.org`, `pypi.python.org`, `pythonhosted.org`, `files.pythonhosted.org`

## Notebook Walkthrough

| # | Cell Name | What It Does |
|---|-----------|-------------|
| 1 | Install Snowpark Connect | `pip install snowpark-connect[jdk]` |
| 2 | Initialize Spark Session | One-line `init_spark_session()` -- replaces cluster bootstrap |
| 3 | Verify Query Warehouse | Shows which warehouse executes queries (two-layer architecture) |
| 4 | Load TPC-H Dataset | `spark.read.table()` on 600M rows -- zero data movement |
| 5 | Explore Dataset with SQL | SQL magic cell to preview data |
| 6 | Print Schema / Sample | Schema inspection and data preview |
| 7 | Ship Mode Distribution | GroupBy + Window functions over 600M rows |
| 8 | Yearly Aggregation | Year-over-year stats with sum, avg, count |
| 9 | Keyword Search | Text matching across 600M records |
| 10 | Multi-Pattern Scan | CASE-based pattern classification via `spark.sql()` |
| 11 | UDFs | Three Python UDFs: classify, extract keywords, match score |
| 12 | Apply UDFs | Run UDFs on 100K records |
| 13 | Similarity Search | UDF-based scoring against search terms |
| 14 | SQL Passthrough | Create Snowflake-native Python UDF via `spark.sql()` |
| 15 | Full Corpus Stats | Aggregation over all 600M rows |
| 16 | Complex CTE Query | CTE + multi-pattern + aggregation |
| 17 | Write Results | `saveAsTable()` -- 1M classified records to Snowflake table |
| 18 | Cleanup | `spark.stop()` |

## Performance Notes

Each cell takes approximately **30-45 seconds** to complete, even though the Snowflake query itself may only run for a few seconds. This is expected behavior:

```
Cell execution timeline:
|-- Plan compile (client) --|-- Transmit --|-- Warehouse query --|-- Serialize results --|
|        ~5-10s             |    ~1-2s     |      ~3-8s          |       ~10-20s         |
                                                                        Total: ~30-45s
```

The overhead comes from the **Spark Connect round-trip**:
1. **Plan compilation** -- PySpark compiles the DataFrame operations into a query plan on the client
2. **Transmission** -- The plan is sent to Snowflake via the Spark Connect protocol
3. **Query execution** -- The warehouse executes the SQL (this is the fast part -- check Query History)
4. **Result serialization** -- Results are serialized and sent back to the client container

This is inherent to the Spark Connect architecture (lazy evaluation + client-server separation) and is not a performance issue. In production, you'd typically chain operations and only trigger execution at the end.

## Dataset

**TPC-H SF100 LINEITEM** -- ~600 million rows

Available in every Snowflake account at `SNOWFLAKE_SAMPLE_DATA.TPCH_SF100.LINEITEM`. No setup required.

Key columns used in the demo:
- `L_COMMENT` -- Free-text field used for text search and classification
- `L_EXTENDEDPRICE` -- Numeric field for aggregations
- `L_SHIPMODE`, `L_SHIPDATE` -- Categorical/date fields for grouping
- `L_ORDERKEY` -- Order identifier for joins and counts

## Cleanup

Run `setup/03_cleanup.sql` to drop all resources created by the demo:
- Output tables (`CLASSIFIED_COMMENTS`)
- Snowflake UDFs (`TEXT_SIMILARITY_SCORE`)
- Warehouse (`SPARK_CONNECT_WH`)
- Compute pool (`SPARK_CONNECT_POOL`)
- Network rule and EAI

## File Structure

```
keystone-sparkconnect-demo/
  README.md                                         -- This file
  notebook/
    keystone_spark_connect_text_processing.ipynb     -- Main demo notebook
  setup/
    01_prerequisites.sql    -- Warehouse, compute pool, EAI, database
    02_git_integration.sql  -- Optional: Git repo integration for workspace
    03_cleanup.sql          -- Teardown script
```

---

*Snowpark Connect for Apache Spark is available in Public Preview.*
