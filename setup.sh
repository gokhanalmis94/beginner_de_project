cd airflow/
mkdir logs
mkdir temp
docker-compose up airflow-init
docker-compose up -d
sleep 300

docker exec -d airflow_airflow-webserver_1 airflow variables set BUCKET galmis-data-lake-batch-de-project
docker exec -d airflow_airflow-webserver_1 airflow variables set EMR_ID j-2QCTGJJZOX5X6
docker exec -d airflow_airflow-webserver_1 airflow connections add 'postgres_default' --conn-type 'Postgres' --conn-login 'airflow' --conn-password 'airflow' --conn-host 'localhost' --conn-port 5432 --conn-schema 'airflow'

