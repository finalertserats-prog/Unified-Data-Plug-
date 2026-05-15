from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, lit, col, sum as spark_sum, count as spark_count

spark = (
    SparkSession.builder
    .appName("UDP Bootstrap Demo Lake")
    .getOrCreate()
)

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

# Idempotent demo: replace raw demo table on bootstrap.
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

print("UDP demo lake created:")
print(" - udp.raw.demo_customers")
print(" - udp.curated.demo_customer_summary")

spark.stop()
