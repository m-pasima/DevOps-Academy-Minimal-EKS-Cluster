admin_principal_arn = "arn:aws:iam::084375555179:user/***-user"  # Replace *** with your IAM username
region              = "eu-west-2"
cluster_version     = "1.29"
spot_instance_types = ["t3.small"]
od_instance_types   = ["t3.small"]
enable_nodeport_ingress = false
nodeport_cidrs      = ["0.0.0.0/0"]
