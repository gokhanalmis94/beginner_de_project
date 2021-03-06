from datetime import datetime, timedelta
import json

from airflow import DAG
from airflow.contrib.operators.emr_add_steps_operator import EmrAddStepsOperator
from airflow.contrib.sensors.emr_step_sensor import EmrStepSensor
from airflow.models import Variable
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.postgres_operator import PostgresOperator
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator

from utils import _local_to_s3

# Config
BUCKET_NAME = Variable.get("BUCKET")
EMR_ID = Variable.get("EMR_ID")
EMR_STEPS = {}
with open("./dags/scripts/emr/clean_movie_review.json") as json_file:
    EMR_STEPS = json.load(json_file)

# DAG definition
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "wait_for_downstream": True,
    "start_date": datetime(2022, 1, 21),
    "email": ["galmis@babbel.com"],
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

dag = DAG(
    "user_behaviour",
    default_args=default_args,
    schedule_interval="*/40 * * * *",
    max_active_runs=1,
)

extract_user_purchase_data = PostgresOperator(
    dag=dag,
    task_id="extract_user_purchase_data",
    sql="./scripts/sql/unload_user_purchase.sql",
    postgres_conn_id="postgres_default",
    params={"user_purchase": "/temp/user_purchase.csv"},
    depends_on_past=True,
    wait_for_downstream=True,
)

user_purchase_to_stage_data_lake = PythonOperator(
    dag=dag,
    task_id="user_purchase_to_stage_data_lake",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "/temp/user_purchase.csv",
        "key": "stage/user_purchase/{{ ds }}_user_purchase.csv",
        "bucket_name": BUCKET_NAME,
        "remove_local": "true",
    },
)

movie_review_to_raw_data_lake = PythonOperator(
    dag=dag,
    task_id="movie_review_to_raw_data_lake",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "/data/movie_review.csv",
        "key": "raw/movie_review/{{ ds }}_movie.csv",
        "bucket_name": BUCKET_NAME,
    },
)

spark_script_to_s3 = PythonOperator(
    dag=dag,
    task_id="spark_script_to_s3",
    python_callable=_local_to_s3,
    op_kwargs={
        "file_name": "./dags/scripts/spark/random_text_classification.py",
        "key": "scripts/random_text_classification.py",
        "bucket_name": BUCKET_NAME,
    },
)

start_emr_movie_classification_script = EmrAddStepsOperator(
    dag=dag,
    task_id="start_emr_movie_classification_script",
    job_flow_id=EMR_ID,
    aws_conn_id="aws_default",
    steps=EMR_STEPS,
    params={
        "BUCKET_NAME": BUCKET_NAME,
        "raw_movie_review": "raw/movie_review",
        "text_classifier_script": "scripts/random_text_classifier.py",
        "stage_movie_review": "stage/movie_review",
    },
    depends_on_past=True,
)

last_step = len(EMR_STEPS) - 1

wait_for_movie_classification_transformation = EmrStepSensor(
    dag=dag,
    task_id="wait_for_movie_classification_transformation",
    job_flow_id=EMR_ID,
    step_id='{{ task_instance.xcom_pull("start_emr_movie_classification_script", key="return_value")['
    + str(last_step)
    + "] }}",
    depends_on_past=True,
)

wait_for_external_tables_refresh = BashOperator(
        dag = dag,
        task_id='wait_for_external_tables_refresh',
        depends_on_past=True,
        bash_command='sleep 30',
        retries=3,
    )


SNOWFLAKE_CONN_ID = 'snowflake_default'

# SQL commands
snowflake_sql_string = """
DELETE FROM user_behavior_metric
WHERE insert_date = '{{ ds }}';
ALTER EXTERNAL TABLE classified_movie_review REFRESH;
ALTER EXTERNAL TABLE user_purchase_staging REFRESH;
INSERT INTO user_behavior_metric (
        customerid,
        amount_spent,
        review_score,
        review_count,
        insert_date
    )
    SELECT ups.customerid,
        CAST(
            SUM(ups.Quantity * ups.UnitPrice) AS DECIMAL(18, 5)
        ) AS amount_spent,
        SUM(mrcs.positive_review) AS review_score,
        count(mrcs.cid) AS review_count,
        TO_DATE('{{ ds }}')
        FROM user_purchase_staging ups
            JOIN (
                SELECT cid,
                    CASE
                        WHEN positive_review = True THEN 1
                        ELSE 0
                    END AS positive_review
                FROM classified_movie_review
                WHERE insert_date = '{{ ds }}'
            ) mrcs ON ups.customerid = mrcs.cid
    GROUP BY ups.customerid;
"""

generate_user_behavior_metric = SnowflakeOperator(
    task_id='generate_user_behavior_metric',
    dag=dag,
    snowflake_conn_id="snowflake_default",
    sql=snowflake_sql_string,
)

end_of_data_pipeline = DummyOperator(task_id="end_of_data_pipeline", dag=dag)

extract_user_purchase_data >> user_purchase_to_stage_data_lake
[
    movie_review_to_raw_data_lake,
    spark_script_to_s3,
] >> start_emr_movie_classification_script >> wait_for_movie_classification_transformation
[
    user_purchase_to_stage_data_lake,
    wait_for_movie_classification_transformation,
] >> wait_for_external_tables_refresh >> generate_user_behavior_metric >> end_of_data_pipeline