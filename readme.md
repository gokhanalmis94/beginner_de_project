## Adaptation of the [data engineering project](https://www.startdataengineering.com/post/data-engineering-project-for-beginners-batch-edition/) by Joseph Machado

### Objective:
Creating a complex data pipeline with multiple components mimicking real-word data engineering processes

### Details
The pipeline consists of two data resources: user_purchases and movie_reviews.
- User_purchase is stored in Postgres container of Airflow to replicate an internal database. /Airflow/data is mounted to provide initialization data. Postgres script is placed in /Airflow/pgsetup to initiate the table. Airflow extracts CSVs from the Postgres database and send it to /stage area in S3 in CSV format.
- movie_reviews are stored as CSV files in /Airflow/data path to replicate data coming from external partners in real workflows. Airflow uploads the data to S3 and starts EMR cluster to start review classification. Classification script '/airflow/dags/scripts/spark/random_text_classification.py' converts the data to positive_review = True/False. Then the file is uplaoded to /stage area of S3 in CSV format.
- Two external tables in Snowflake point to these S3 files.
- In the end, user_purchases and classified_movie_reviews are combined to create the OLAP table.

### Original Pipeline from Joseph Machado's project
![Original Pipeline](https://www.startdataengineering.com/images/de_project_for_beginners/de_proj_design.png)

### What is changed in this version
- Infrastructure is created with Terraform rather than bash script
- Local Airflow built with a newer version and with celery executor due to better performance
- Rather than Redshift and Redshift Spectrum, Snowflake and its external tables are used for similarity with Babbel processes

### Setup
#### Requirements
- Docker with Docker-compose and at least 4GB of RAM
- AWS account with AWS CLI installed and configured
- Snowflake account
- Terraform installed

#### Installation Steps
- Get the raw data from original project's bucket and unpack
```
aws s3 cp s3://start-data-engg/data.zip ./
unzip data.zip
```
- Create Airflow mounted folders and move raw data there
```
mkdir airflow/logs
mkdir airflow/data
mv data/* airflow/data/
```
- Start Airflow containers and wait 5mins for a healthy state
```
docker-compose up airflow-init
docker-compose up -d
sleep 300
```
- Starting Terraform for infrastructure
```
terraform init
terraform apply -auto-approve
```
- Adding S3 bucket name to Airflow variables 
```
docker exec -d airflow_airflow-webserver_1 airflow variables set BUCKET $(terraform output bucket_name)
```
- Adding EMR Cluster ID to Airflow variables
```
docker exec -d airflow_airflow-webserver_1 airflow variables set EMR_ID $(terraform output emr_id)
```
- Adding Postgres connection to Airflow connections for raw user_purcase data
```
docker exec -d airflow_airflow-webserver_1 airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'
```
- Adding AWS connection to Airflow connections
```
docker exec -d airflow_airflow-webserver_1 airflow connections add 'aws_default' --conn-type 'aws' --conn-login $(aws configure get aws_access_key_id) --conn-password $(aws configure get aws_secret_access_key) --conn-extra '{"region_name":"eu-west-1", "role_arn":"$(aws configure get role_arn)"}'
```
