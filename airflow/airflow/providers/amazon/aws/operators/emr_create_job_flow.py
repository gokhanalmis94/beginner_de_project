#
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
import ast
from datetime import datetime
from typing import Any, Dict, Optional, Union

from airflow.exceptions import AirflowException
from airflow.models import BaseOperator, BaseOperatorLink, TaskInstance
from airflow.providers.amazon.aws.hooks.emr import EmrHook


class EmrClusterLink(BaseOperatorLink):
    """Operator link for EmrCreateJobFlowOperator. It allows users to access the EMR Cluster"""

    name = 'EMR Cluster'

    def get_link(self, operator: BaseOperator, dttm: datetime) -> str:
        """
        Get link to EMR cluster.

        :param operator: operator
        :param dttm: datetime
        :return: url link
        """
        ti = TaskInstance(task=operator, execution_date=dttm)
        flow_id = ti.xcom_pull(task_ids=operator.task_id)
        return (
            f'https://console.aws.amazon.com/elasticmapreduce/home#cluster-details:{flow_id}'
            if flow_id
            else ''
        )


class EmrCreateJobFlowOperator(BaseOperator):
    """
    Creates an EMR JobFlow, reading the config from the EMR connection.
    A dictionary of JobFlow overrides can be passed that override
    the config from the connection.

    :param aws_conn_id: aws connection to uses
    :type aws_conn_id: str
    :param emr_conn_id: emr connection to use
    :type emr_conn_id: str
    :param job_flow_overrides: boto3 style arguments or reference to an arguments file
        (must be '.json') to override emr_connection extra. (templated)
    :type job_flow_overrides: dict|str
    :param region_name: Region named passed to EmrHook
    :type region_name: Optional[str]
    """

    template_fields = ['job_flow_overrides']
    template_ext = ('.json',)
    template_fields_renderers = {"job_flow_overrides": "json"}
    ui_color = '#f9c915'
    operator_extra_links = (EmrClusterLink(),)

    def __init__(
        self,
        *,
        aws_conn_id: str = 'aws_default',
        emr_conn_id: str = 'emr_default',
        job_flow_overrides: Optional[Union[str, Dict[str, Any]]] = None,
        region_name: Optional[str] = None,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self.aws_conn_id = aws_conn_id
        self.emr_conn_id = emr_conn_id
        if job_flow_overrides is None:
            job_flow_overrides = {}
        self.job_flow_overrides = job_flow_overrides
        self.region_name = region_name

    def execute(self, context: Dict[str, Any]) -> str:
        emr = EmrHook(
            aws_conn_id=self.aws_conn_id, emr_conn_id=self.emr_conn_id, region_name=self.region_name
        )

        self.log.info(
            'Creating JobFlow using aws-conn-id: %s, emr-conn-id: %s', self.aws_conn_id, self.emr_conn_id
        )

        if isinstance(self.job_flow_overrides, str):
            job_flow_overrides: Dict[str, Any] = ast.literal_eval(self.job_flow_overrides)
            self.job_flow_overrides = job_flow_overrides
        else:
            job_flow_overrides = self.job_flow_overrides
        response = emr.create_job_flow(job_flow_overrides)

        if not response['ResponseMetadata']['HTTPStatusCode'] == 200:
            raise AirflowException(f'JobFlow creation failed: {response}')
        else:
            self.log.info('JobFlow with id %s created', response['JobFlowId'])
            return response['JobFlowId']
