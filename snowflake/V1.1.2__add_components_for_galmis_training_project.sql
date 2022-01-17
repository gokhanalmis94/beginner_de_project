-- data_engineering database for training project
USE DATABASE "DATA_ENGINEERING"

-- create schema for the external and end table
CREATE OR REPLACE SCHEMA IF NOT EXISTS "galmis";

-- create storage integration for the staging external table
CREATE STORAGE INTEGRATION IF NOT EXISTS
  galmis_training_project
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::301581146302:role/galmis_snowflake_storage_integration_role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://galmis-data-lake-batch-de-project/stage/');

-- use training schema for the rest of the code
USE SCHEMA "galmis";

-- creating the stage for the below 2 external tables
CREATE OR REPLACE STAGE IF NOT EXISTS galmis_training_project_stage
  URL = 's3://galmis-data-lake-batch-de-project/stage/'
  STORAGE_INTEGRATION = galmis_training_project;

-- creating external table for staging user purchases
CREATE OR REPLACE EXTERNAL TABLE IF NOT EXISTS
  user_purchase_staging
    (InvoiceNo VARCHAR(10),
    StockCode VARCHAR(20),
    detail VARCHAR(1000),
    Quantity INTEGER,
    InvoiceDate TIMESTAMP,
    UnitPrice DECIMAL(8,3),
    customerid INTEGER,
    Country VARCHAR(20))
  WITH LOCATION = @galmis_training_project_stage/user_purchase/
  REFRESH_ON_CREATE =  TRUE
  AUTO_REFRESH = TRUE
  PATTERN = '.*_user_purchase[.]csv'
  FILE_FORMAT = (TYPE = CSV)
  AWS_SNS_TOPIC = 'arn:aws:sns:eu-west-1:301581146302:galmis_training_user_purchase';

-- creating external table for staging user movie revies
CREATE OR REPLACE EXTERNAL TABLE IF NOT EXISTS
  classified_movie_review
    (cid VARCHAR(100),
    positive_review boolean,
    insert_date VARCHAR(12))
  WITH LOCATION = @galmis_training_project_stage/movie_review/
  REFRESH_ON_CREATE =  TRUE
  AUTO_REFRESH = TRUE
  PATTERN = '.*_movie[.]csv'
  FILE_FORMAT = (TYPE = CSV)
  AWS_SNS_TOPIC = 'arn:aws:sns:eu-west-1:301581146302:galmis_training_movie_review';

-- creating the end table for combined movie reviews and user purchases
CREATE TABLE user_behavior_metric (
  customerid INTEGER,
  amount_spent DECIMAL(18, 5),
  review_score INTEGER,
  review_count INTEGER,
  insert_date DATE
);
