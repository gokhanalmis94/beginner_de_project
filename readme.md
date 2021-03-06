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
- Terraform CLI

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
mkdir airflow/temp
mv data/* airflow/data/
```
- Start Airflow containers and wait 5mins for a healthy state
```
docker-compose build
docker-compose up airflow-init
docker-compose up -d
sleep 300
```
- Starting Terraform for infrastructure
```
terraform init
terraform apply -auto-approve
```
- Follow [this documentation of Snowflake](https://docs.snowflake.com/en/user-guide/tables-external-s3.html) to create a storage integration and stage from S3
- Run the SQL queries in /snowflake/ to create the required Snowflake storage integration, stage and tables. Skip storage integration and stage if you already did them in the previous phase.
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
- Adding AWS connection to Airflow connections. Replace {AWS_ROLE_ARN} with your own role ARN
```
docker exec -d airflow_airflow-webserver_1 airflow connections add 'aws_default' --conn-type 'aws' --conn-login $(aws configure get aws_access_key_id) --conn-password $(aws configure get aws_secret_access_key) --conn-extra '{"region_name":"eu-west-1", "role_arn":"{AWS_ROLE_ARN}"}'
```
- Adding Snowflake connection to Airflow. Replace sections in {} with your own credentials
```
docker exec -d airflow_airflow-webserver_1 airflow connections add 'snowflake_default' --conn-type 'snowflake' --conn-login {SNOWFLAKE_USERNAME} --conn-password {SNOWFLAKE_PASSWORD} --conn-schema {SNOWFLAKE_SCHEMA} --conn-account {SNOWFLAKE_ACCOUNT} --conn-extra '{"extra__snowflake__account": "az36725.eu-west-1", "extra__snowflake__aws_access_key_id": "", "extra__snowflake__aws_secret_access_key": "", "extra__snowflake__database": "{SF_DATABASE}", "extra__snowflake__region": "", "extra__snowflake__role": "{SF_ROLE}", "extra__snowflake__warehouse": "{SF_WAREHOUSE}", "private_key_file": "{SF_PRIVATE_KEY_FILE}"}'
```
- Connect to [Airflow webserver](http://localhost:8080/) with the default credentials and activate the user_behaviour tag

### Currently Known Issues
- Pipeline gets all data from user_purchases Postgres table every time.
- IAM role and policy Snowflake storage integration created manually while following Snowflake guide, not from Terraform