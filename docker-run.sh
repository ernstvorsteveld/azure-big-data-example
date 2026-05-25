docker run -d \
  --name local-spark-iceberg \
  -p 8888:8888 \
  -p 8080:8080 \
  -e SPARK_DEFAULTS_CONF='["spark.sql.catalog.sandbox=org.apache.iceberg.spark.SparkCatalog","spark.sql.catalog.sandbox.type=hadoop","spark.sql.catalog.sandbox.warehouse=abfss://iceberg-warehouse@'$AZ_STORAGE_ACCOUNT'.dfs.core.windows.net/warehouse","spark.hadoop.fs.azure.account.key.'$AZ_STORAGE_ACCOUNT'.dfs.core.windows.net='$AZ_STORAGE_KEY'"]' \
  tabulario/spark-iceberg:latest
