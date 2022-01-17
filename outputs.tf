output "emr_id" {
  value = "${aws_emr_cluster.cluster.id}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.datalake-s3.id}"
}