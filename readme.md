### Adaptation of the data engineering project https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition/

These components have been changed to make the project more similar to Babbel DP processes:
- Infrastructure is created with Terraform
- Local Airflow built with a newer version and with celery executor
- Snowflake and external tables have been used rather in the place of Redshift from the original project.