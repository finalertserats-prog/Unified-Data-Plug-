from pyspark.sql import SparkSession

spark = SparkSession.builder.appName("UDP Iceberg Smoke Test").getOrCreate()

raw_count = spark.table("udp.raw.demo_customers").count()
curated_count = spark.table("udp.curated.demo_customer_summary").count()

print(f"raw.demo_customers rows = {raw_count}")
print(f"curated.demo_customer_summary rows = {curated_count}")

assert raw_count == 5, f"Expected 5 raw rows, got {raw_count}"
assert curated_count >= 1, f"Expected curated rows, got {curated_count}"

spark.stop()
