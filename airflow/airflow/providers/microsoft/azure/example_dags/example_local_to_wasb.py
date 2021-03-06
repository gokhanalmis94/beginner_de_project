# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

import os

from airflow.models import DAG
from airflow.providers.microsoft.azure.operators.wasb_delete_blob import WasbDeleteBlobOperator
from airflow.providers.microsoft.azure.transfers.local_to_wasb import LocalFilesystemToWasbOperator
from airflow.utils.dates import days_ago

PATH_TO_UPLOAD_FILE = os.environ.get('AZURE_PATH_TO_UPLOAD_FILE', 'example-text.txt')

with DAG("example_local_to_wasb", schedule_interval="@once", start_date=days_ago(2)) as dag:
    upload = LocalFilesystemToWasbOperator(
        task_id="upload_file", file_path=PATH_TO_UPLOAD_FILE, container_name="mycontainer", blob_name='myblob'
    )
    delete = WasbDeleteBlobOperator(task_id="delete_file", container_name="mycontainer", blob_name="myblob")
    upload >> delete
