-- data_engineering database for training project
USE DATABASE data_engineering;

-- create schema for the external and end table
CREATE SCHEMA IF NOT EXISTS galmis;

-- create storage integration for the staging external table
CREATE STORAGE INTEGRATION IF NOT EXISTS
  galmis_training_project
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::301581146302:role/galmis_snowflake_storage_integration_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://galmis-data-lake-batch-de-project/stage/');

-- use training schema for the rest of the code
USE SCHEMA galmis;

-- creating the stage for the below 2 external tables
CREATE STAGE IF NOT EXISTS galmis_training_project_stage
  URL = 's3://galmis-data-lake-batch-de-project/stage/'
  STORAGE_INTEGRATION = galmis_training_project;

-- granting usage access to new resources for troubleshooting
GRANT USAGE ON INTEGRATION galmis_training_project TO ROLE de_trainee;
GRANT USAGE ON STAGE galmis_training_project_stage TO ROLE de_trainee;

-- creating external table for staging user purchases
CREATE EXTERNAL TABLE IF NOT EXISTS
  user_purchase_staging
    (InvoiceNo VARCHAR(10) AS (value:c1::varchar),
    StockCode VARCHAR(20) AS (value:c2::varchar),
    detail VARCHAR(1000) AS (value:c3::varchar),
    Quantity INTEGER AS (value:c4::integer),
    InvoiceDate TIMESTAMP AS (value:c5::timestamp),
    UnitPrice DECIMAL(8,3) AS (value:c6::decimal),
    customerid INTEGER AS (value:c7::integer),
    Country VARCHAR(20) AS (value:c8::varchar))
  WITH LOCATION = @galmis_training_project_stage/user_purchase/
  REFRESH_ON_CREATE =  TRUE
  AUTO_REFRESH = TRUE
  PATTERN = '.*_user_purchase[.]csv'
  FILE_FORMAT = (
    TYPE = CSV
    COMPRESSION = NONE
    RECORD_DELIMITER = '\n'
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 1
    SKIP_BLANK_LINES = FALSE)
  AWS_SNS_TOPIC = 'arn:aws:sns:eu-west-1:301581146302:galmis_training_user_purchase';

-- creating external table for staging user movie revies
CREATE EXTERNAL TABLE IF NOT EXISTS
  classified_movie_review
    (cid VARCHAR(100) AS (value:c1::varchar),
    positive_review boolean AS (value:c2::boolean),
    insert_date VARCHAR(12) AS (value:c3::varchar))
  WITH LOCATION = @galmis_training_project_stage/movie_review/
  REFRESH_ON_CREATE =  TRUE
  AUTO_REFRESH = TRUE
  PATTERN = '.*[.]csv'
  FILE_FORMAT = (
    TYPE = CSV
    COMPRESSION = NONE
    RECORD_DELIMITER = '\n'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 0
    SKIP_BLANK_LINES = FALSE)
  AWS_SNS_TOPIC = 'arn:aws:sns:eu-west-1:301581146302:galmis_training_movie_review';

-- creating the end table for combined movie reviews and user purchases
CREATE TABLE IF NOT EXISTS
  user_behavior_metric 
    (customerid INTEGER,
    amount_spent DECIMAL(18, 5),
    review_score INTEGER,
    review_count INTEGER,
    insert_date DATE
);
