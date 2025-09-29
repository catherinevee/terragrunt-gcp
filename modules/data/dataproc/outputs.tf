# Dataproc Module Outputs

# Cluster Information
output "cluster_name" {
  description = "Name of the Dataproc cluster"
  value       = try(google_dataproc_cluster.cluster[0].name, null)
}

output "cluster_id" {
  description = "ID of the Dataproc cluster"
  value       = try(google_dataproc_cluster.cluster[0].id, null)
}

output "cluster_uuid" {
  description = "UUID of the Dataproc cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].cluster_uuid, null)
}

output "cluster_state" {
  description = "State of the Dataproc cluster"
  value       = try(google_dataproc_cluster.cluster[0].status[0].state, null)
}

output "cluster_state_time" {
  description = "Time when cluster entered current state"
  value       = try(google_dataproc_cluster.cluster[0].status[0].state_start_time, null)
}

output "cluster_detail" {
  description = "Detailed status message"
  value       = try(google_dataproc_cluster.cluster[0].status[0].detail, null)
}

output "cluster_substate" {
  description = "Cluster substate"
  value       = try(google_dataproc_cluster.cluster[0].status[0].substate, null)
}

# Master Configuration
output "master_instance_names" {
  description = "Names of master instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].master_config[0].instance_names, [])
}

output "master_machine_type" {
  description = "Machine type of master nodes"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].master_config[0].machine_type, null)
}

output "master_num_instances" {
  description = "Number of master instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].master_config[0].num_instances, null)
}

# Worker Configuration
output "worker_instance_names" {
  description = "Names of worker instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].worker_config[0].instance_names, [])
}

output "worker_machine_type" {
  description = "Machine type of worker nodes"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].worker_config[0].machine_type, null)
}

output "worker_num_instances" {
  description = "Number of worker instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].worker_config[0].num_instances, null)
}

output "worker_min_num_instances" {
  description = "Minimum number of worker instances (autoscaling)"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].worker_config[0].min_num_instances, null)
}

# Preemptible Worker Configuration
output "preemptible_worker_instance_names" {
  description = "Names of preemptible worker instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].preemptible_worker_config[0].instance_names, [])
}

output "preemptible_worker_num_instances" {
  description = "Number of preemptible worker instances"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].preemptible_worker_config[0].num_instances, null)
}

# Software Configuration
output "image_version" {
  description = "Dataproc image version"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].software_config[0].image_version, null)
}

output "software_properties" {
  description = "Software configuration properties"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].software_config[0].properties, {})
}

output "optional_components" {
  description = "Optional components installed"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].software_config[0].optional_components, [])
}

# Network Configuration
output "network" {
  description = "Network used by the cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].gce_cluster_config[0].network, null)
}

output "subnetwork" {
  description = "Subnetwork used by the cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].gce_cluster_config[0].subnetwork, null)
}

output "zone" {
  description = "Zone where cluster is deployed"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].gce_cluster_config[0].zone, null)
}

output "internal_ip_only" {
  description = "Whether cluster uses internal IPs only"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].gce_cluster_config[0].internal_ip_only, false)
}

# Storage
output "staging_bucket" {
  description = "Staging bucket for the cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].staging_bucket, null)
}

output "temp_bucket" {
  description = "Temp bucket for the cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].temp_bucket, null)
}

output "created_staging_bucket" {
  description = "Name of created staging bucket"
  value       = try(google_storage_bucket.staging_bucket[0].name, null)
}

output "created_staging_bucket_url" {
  description = "URL of created staging bucket"
  value       = try(google_storage_bucket.staging_bucket[0].url, null)
}

# Endpoints
output "endpoint_config" {
  description = "Endpoint configuration"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0], null)
}

output "http_ports" {
  description = "HTTP ports exposed"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0].http_ports, {})
}

# Autoscaling
output "autoscaling_policy_id" {
  description = "ID of the autoscaling policy"
  value       = try(google_dataproc_autoscaling_policy.autoscaling_policy[0].id, null)
}

output "autoscaling_policy_name" {
  description = "Name of the autoscaling policy"
  value       = try(google_dataproc_autoscaling_policy.autoscaling_policy[0].policy_id, null)
}

output "autoscaling_policy_uri" {
  description = "URI of the autoscaling policy"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].autoscaling_config[0].policy_uri, null)
}

# Metastore
output "metastore_service_id" {
  description = "ID of the metastore service"
  value       = try(google_dataproc_metastore_service.metastore[0].id, null)
}

output "metastore_service_name" {
  description = "Name of the metastore service"
  value       = try(google_dataproc_metastore_service.metastore[0].service_id, null)
}

output "metastore_service_state" {
  description = "State of the metastore service"
  value       = try(google_dataproc_metastore_service.metastore[0].state, null)
}

output "metastore_service_endpoint_uri" {
  description = "Endpoint URI of the metastore service"
  value       = try(google_dataproc_metastore_service.metastore[0].endpoint_uri, null)
}

output "metastore_port" {
  description = "Port of the metastore service"
  value       = try(google_dataproc_metastore_service.metastore[0].port, null)
}

# Security
output "service_account" {
  description = "Service account used by the cluster"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].gce_cluster_config[0].service_account, null)
}

output "kerberos_enabled" {
  description = "Whether Kerberos is enabled"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].security_config[0].kerberos_config[0].enable_kerberos, false)
}

output "kerberos_realm" {
  description = "Kerberos realm"
  value       = try(google_dataproc_cluster.cluster[0].cluster_config[0].security_config[0].kerberos_config[0].realm, null)
}

# Job Outputs
output "spark_jobs" {
  description = "Deployed Spark jobs"
  value = {
    for job_name, job in google_dataproc_job.spark_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "pyspark_jobs" {
  description = "Deployed PySpark jobs"
  value = {
    for job_name, job in google_dataproc_job.pyspark_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "hive_jobs" {
  description = "Deployed Hive jobs"
  value = {
    for job_name, job in google_dataproc_job.hive_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "pig_jobs" {
  description = "Deployed Pig jobs"
  value = {
    for job_name, job in google_dataproc_job.pig_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "hadoop_jobs" {
  description = "Deployed Hadoop jobs"
  value = {
    for job_name, job in google_dataproc_job.hadoop_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "sparksql_jobs" {
  description = "Deployed SparkSQL jobs"
  value = {
    for job_name, job in google_dataproc_job.sparksql_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

output "presto_jobs" {
  description = "Deployed Presto jobs"
  value = {
    for job_name, job in google_dataproc_job.presto_job :
    job_name => {
      id            = job.id
      status        = job.status[0].state
      driver_output = try(job.driver_output_resource_uri, null)
      labels        = job.labels
    }
  }
}

# Workflow Template
output "workflow_template_id" {
  description = "ID of the workflow template"
  value       = try(google_dataproc_workflow_template.workflow[0].id, null)
}

output "workflow_template_name" {
  description = "Name of the workflow template"
  value       = try(google_dataproc_workflow_template.workflow[0].name, null)
}

output "workflow_template_version" {
  description = "Version of the workflow template"
  value       = try(google_dataproc_workflow_template.workflow[0].version, null)
}

# Virtual Cluster Configuration (for GKE-based clusters)
output "virtual_cluster_config" {
  description = "Virtual cluster configuration"
  value       = try(google_dataproc_cluster.cluster[0].virtual_cluster_config[0], null)
}

output "kubernetes_namespace" {
  description = "Kubernetes namespace for virtual cluster"
  value       = try(google_dataproc_cluster.cluster[0].virtual_cluster_config[0].kubernetes_cluster_config[0].kubernetes_namespace, null)
}

output "gke_cluster_target" {
  description = "Target GKE cluster"
  value       = try(google_dataproc_cluster.cluster[0].virtual_cluster_config[0].kubernetes_cluster_config[0].gke_cluster_config[0].gke_cluster_target, null)
}

# Labels
output "labels" {
  description = "Labels attached to the cluster"
  value       = try(google_dataproc_cluster.cluster[0].labels, {})
}

# Console URLs
output "console_urls" {
  description = "Google Cloud Console URLs"
  value = {
    cluster = var.deploy_cluster ? (
      "https://console.cloud.google.com/dataproc/clusters/${local.cluster_name}?region=${var.region}&project=${var.project_id}"
    ) : null

    jobs = "https://console.cloud.google.com/dataproc/jobs?region=${var.region}&project=${var.project_id}"

    workflows = "https://console.cloud.google.com/dataproc/workflows/instances?project=${var.project_id}"

    metastore = var.create_metastore ? (
      "https://console.cloud.google.com/dataproc/metastore/${try(google_dataproc_metastore_service.metastore[0].service_id, "")}?project=${var.project_id}"
    ) : null

    staging_bucket = var.create_staging_bucket ? (
      "https://console.cloud.google.com/storage/browser/${try(google_storage_bucket.staging_bucket[0].name, "")}?project=${var.project_id}"
    ) : null
  }
}

# Component Gateway URLs
output "component_gateway_urls" {
  description = "Component gateway URLs"
  value = var.deploy_cluster && var.enable_component_gateway ? {
    yarn_resourcemanager = "https://${try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0].http_ports["YARN ResourceManager"], "")}"
    spark_history_server = "https://${try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0].http_ports["Spark History Server"], "")}"
    hdfs_namenode        = "https://${try(google_dataproc_cluster.cluster[0].cluster_config[0].http_ports["HDFS NameNode"], "")}"
    mapreduce_history    = "https://${try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0].http_ports["MapReduce History Server"], "")}"
    jupyter              = var.enable_jupyter ? "https://${try(google_dataproc_cluster.cluster[0].cluster_config[0].endpoint_config[0].http_ports["Jupyter"], "")}" : null
  } : null
}

# gcloud Commands
output "gcloud_commands" {
  description = "Useful gcloud commands"
  value = {
    describe_cluster = var.deploy_cluster ? (
      "gcloud dataproc clusters describe ${local.cluster_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    ssh_master = var.deploy_cluster && !var.internal_ip_only ? (
      "gcloud compute ssh ${try(google_dataproc_cluster.cluster[0].cluster_config[0].master_config[0].instance_names[0], "")} --zone=${var.zone} --project=${var.project_id}"
    ) : null

    submit_spark_job = var.deploy_cluster ? (
      "gcloud dataproc jobs submit spark --cluster=${local.cluster_name} --region=${var.region} --project=${var.project_id} --class=Main --jars=gs://bucket/jar.jar"
    ) : null

    submit_pyspark_job = var.deploy_cluster ? (
      "gcloud dataproc jobs submit pyspark --cluster=${local.cluster_name} --region=${var.region} --project=${var.project_id} script.py"
    ) : null

    list_jobs = "gcloud dataproc jobs list --region=${var.region} --project=${var.project_id}"

    update_cluster = var.deploy_cluster ? (
      "gcloud dataproc clusters update ${local.cluster_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    delete_cluster = var.deploy_cluster ? (
      "gcloud dataproc clusters delete ${local.cluster_name} --region=${var.region} --project=${var.project_id}"
    ) : null

    instantiate_workflow = var.create_workflow_template ? (
      "gcloud dataproc workflow-templates instantiate ${try(google_dataproc_workflow_template.workflow[0].name, "")} --region=${var.region} --project=${var.project_id}"
    ) : null
  }
}

# Spark Submit Examples
output "spark_submit_examples" {
  description = "Spark submit command examples"
  value = var.deploy_cluster ? {
    spark_pi = "spark-submit --class org.apache.spark.examples.SparkPi --master yarn --deploy-mode cluster /usr/lib/spark/examples/jars/spark-examples.jar 10"

    pyspark_wordcount = "spark-submit --master yarn --deploy-mode cluster gs://dataproc-examples/pyspark/wordcount.py gs://dataproc-examples/data/shakespeare.txt gs://${local.staging_bucket}/output"

    spark_sql = "spark-sql --master yarn -e 'SELECT * FROM default.table LIMIT 10'"

    spark_shell = "spark-shell --master yarn"

    pyspark_shell = "pyspark --master yarn"
  } : null
}

# Import Commands
output "import_commands" {
  description = "Terraform import commands"
  value = {
    cluster = var.deploy_cluster ? (
      "terraform import google_dataproc_cluster.cluster projects/${var.project_id}/regions/${var.region}/clusters/${local.cluster_name}"
    ) : null

    autoscaling_policy = var.create_autoscaling_policy ? (
      "terraform import google_dataproc_autoscaling_policy.autoscaling_policy projects/${var.project_id}/locations/${var.region}/autoscalingPolicies/${try(google_dataproc_autoscaling_policy.autoscaling_policy[0].policy_id, "")}"
    ) : null

    metastore = var.create_metastore ? (
      "terraform import google_dataproc_metastore_service.metastore projects/${var.project_id}/locations/${var.region}/services/${try(google_dataproc_metastore_service.metastore[0].service_id, "")}"
    ) : null

    staging_bucket = var.create_staging_bucket ? (
      "terraform import google_storage_bucket.staging_bucket ${var.project_id}/${try(google_storage_bucket.staging_bucket[0].name, "")}"
    ) : null
  }
}