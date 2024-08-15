#########################################################################################################
## Create eks cluster
#########################################################################################################
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 19.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      cluster_name = var.cluster_name
      most_recent = true
    }
    # aws-ebs-csi-driver = {
    #   most_recent = true
    # }
  }

  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.ecom-sub-pri01.id, aws_subnet.ecom-sub-pri02.id]
  control_plane_subnet_ids = [aws_subnet.ecom-sub-pri01.id, aws_subnet.ecom-sub-pri02.id]
  cluster_additional_security_group_ids = [aws_security_group.ecom-sg-cli.id]

  cloudwatch_log_group_retention_in_days = 1

  fargate_profiles = {
    kube-system = {
      name                 = "kube-system" 
      pod_execution_role_arn = aws_iam_role.eks-fargate-profile.arn
      subnet_ids = [
        aws_subnet.ecom-sub-pri01.id,
        aws_subnet.ecom-sub-pri02.id
      ]
      selectors = [
        {
          namespace = "kube-system"
        }
      ]
    },
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        }
      ]
    }

    mgmt = {
      name = "mgmt"
      selectors = [
        {
          namespace = "mgmt"
        }
      ]
    }
    backend = {
      name = "backend"
      selectors = [
        {
          namespace = "backend"
        }
      ]
    }
  }
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 4.12"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
    common = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}