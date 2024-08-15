resource "aws_iam_role" "ecom-role-ec2cli" {
    
  name = "ecom-role-ec2cli"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", "${aws_iam_policy.ecom_describe_cluster_policy.arn}"]
}

# resource "aws_iam_policy" "ecom_describe_cluster_policy" {
#   name        = "ecom-describe-cluster-policy"
#   description = "Allows to describe EKS clusters"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "eks:DescribeCluster"
#         Effect = "Allow"
#         Resource = "*" 
#       }
#     ]
#   })
# }