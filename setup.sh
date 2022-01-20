aws s3 cp s3://start-data-engg/data.zip ./
unzip data.zip

mkdir airflow/logs
mkdir airflow/data
mv data/* airflow/data/


docker-compose up airflow-init
docker-compose up -d
sleep 300

terraform init
terraform apply -auto-approve

docker exec -d airflow_airflow-webserver_1 airflow variables set BUCKET $(terraform output bucket_name)
docker exec -d airflow_airflow-webserver_1 airflow variables set EMR_ID $(terraform output emr_id)
docker exec -d airflow_airflow-webserver_1 airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'
docker exec -d airflow_airflow-webserver_1 airflow connections add 'aws_default' --conn-type 'aws' --conn-login $(aws configure get aws_access_key_id) --conn-password $(aws configure get aws_secret_access_key) --conn-extra '{"region_name":"eu-west-1", "role_arn":"$(aws configure get role_arn)"}'

