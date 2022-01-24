terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.71.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
  profile = "profile sandbox"

}

# Create the S3 bucket for data lake
resource "aws_s3_bucket" "datalake-s3" {
  bucket = "galmis-data-lake-batch-de-project"
  acl    = "private"

  tags = {
    Name        = "Data Lake for galmis DE project"
    Environment = "Sandbox"
    Owner = "galmis"
  }
}





# EMR Cluster to move & manipulate the data
resource "aws_emr_cluster" "cluster" {
  name          = "galmis-batch-de-project-emr_v4"
  release_label = "emr-6.2.1"
  applications  = ["Hadoop","Spark"]
  scale_down_behavior = "TERMINATE_AT_TASK_COMPLETION"
  termination_protection            = false
  keep_job_flow_alive_when_no_steps = true
  log_uri = "s3://aws-logs-301581146302-eu-west-1/elasticmapreduce/"

  ec2_attributes {
    subnet_id                         = aws_subnet.main.id
    emr_managed_master_security_group = aws_security_group.allow_access.id
    emr_managed_slave_security_group  = aws_security_group.allow_access.id
    instance_profile                  = "arn:aws:iam::301581146302:instance-profile/EMR_EC2_DefaultRole"
  }

  master_instance_group {
    name = "Master - 1"
    instance_type = "m4.large"
    ebs_config {
      size                 = "32"
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }

  core_instance_group {
    instance_type  = "m4.large"
    instance_count = 2

    ebs_config {
      size                 = "32"
      type                 = "gp2"
      volumes_per_instance = 2
    }


    autoscaling_policy = <<EOF
{
"Constraints": {
  "MinCapacity": 1,
  "MaxCapacity": 2
},
"Rules": [
  {
    "Name": "ScaleOutMemoryPercentage",
    "Description": "Scale out if YARNMemoryAvailablePercentage is less than 15",
    "Action": {
      "SimpleScalingPolicyConfiguration": {
        "AdjustmentType": "CHANGE_IN_CAPACITY",
        "ScalingAdjustment": 1,
        "CoolDown": 300
      }
    },
    "Trigger": {
      "CloudWatchAlarmDefinition": {
        "ComparisonOperator": "LESS_THAN",
        "EvaluationPeriods": 1,
        "MetricName": "YARNMemoryAvailablePercentage",
        "Namespace": "AWS/ElasticMapReduce",
        "Period": 300,
        "Statistic": "AVERAGE",
        "Threshold": 15.0,
        "Unit": "PERCENT"
      }
    }
  },
  {
    "Name": "Default-scale-in",
    "Trigger": {
        "CloudWatchAlarmDefinition": {
            "MetricName": "YARNMemoryAvailablePercentage",
            "Unit": "PERCENT",
            "Namespace": "AWS/ElasticMapReduce",
            "Threshold": 75,
            "EvaluationPeriods": 1,
            "Period": 300,
            "ComparisonOperator": "GREATER_THAN",
            "Statistic": "AVERAGE"
        }
    },
    "Description": "",
    "Action": {
        "SimpleScalingPolicyConfiguration": {
            "CoolDown": 300,
            "AdjustmentType": "CHANGE_IN_CAPACITY",
            "ScalingAdjustment": -1
        }
    }
  }
]
}
EOF
  }

  ebs_root_volume_size = 100

  tags = {
    Name        = "EMR for galmis DE project"
    Environment = "Sandbox"
    Owner = "galmis"
  }

  bootstrap_action {
    path = "s3://elasticmapreduce/bootstrap-actions/run-if"
    name = "runif"
    args = ["instance.isMaster=true", "echo running on master node"]
  }


  service_role = "arn:aws:iam::301581146302:role/EMR_DefaultRole"
  autoscaling_role = "arn:aws:iam::301581146302:role/EMR_AutoScaling_DefaultRole"
}