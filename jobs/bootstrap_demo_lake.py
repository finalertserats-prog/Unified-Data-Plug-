"""Bootstrap demo Iceberg tables.

Reads examples/data/customers.csv → udp.raw.demo_customers (Iceberg)
                                  → udp.curated.demo_customer_summary (Iceberg)
Emits start/finish records to app_observability.pipeline_runs via udp_core.
"""
import sys
from pathlib import Path

# Make udp_core importable from the mounted /home/iceberg directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit, col, sum as spark_sum, count as spark_count

try:
    from udp_core.observability.run_tracker import track
except Exception:
    # Tracker is best-effort. If the module can't load (e.g. udp_core not
    # mounted), fall back to a no-op so the bootstrap still completes.
    from contextlib import contextmanager
    @contextmanager
    def track(pipeline):  # type: ignore[no-redef]
        class _NoopRun:
            rows_in = None
            rows_out = None
        yield _NoopRun()


spark = (
    SparkSession.builder
    .appName("UDP Bootstrap Demo Lake")
    .getOrCreate()
)

with track(pipeline="demo_csv_to_raw_to_curated") as run:
    spark.sql("CREATE NAMESPACE IF NOT EXISTS udp.raw")
    spark.sql("CREATE NAMESPACE IF NOT EXISTS udp.curated")

    df = (
        spark.read
        .option("header", True)
        .option("inferSchema", True)
        .csv("/home/iceberg/examples/data/customers.csv")
        .withColumn("ingestion_timestamp", current_timestamp())
        .withColumn("source_system", lit("udp_demo"))
        .withColumn("batch_id", lit("demo_bootstrap"))
    )

    run.rows_in = df.count()
    df.writeTo("udp.raw.demo_customers").createOrReplace()

    curated = (
        df.groupBy("region")
        .agg(
            spark_count("customer_id").alias("customer_count"),
            spark_sum(col("order_amount")).alias("total_order_amount")
        )
        .withColumn("curated_timestamp", current_timestamp())
    )
    curated.writeTo("udp.curated.demo_customer_summary").createOrReplace()
    run.rows_out = curated.count()

    print("UDP demo lake created:")
    print(f" - udp.raw.demo_customers ({run.rows_in} rows)")
    print(f" - udp.curated.demo_customer_summary ({run.rows_out} rows)")

spark.stop()
