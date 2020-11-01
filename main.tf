data "aws_iam_policy_document" "WebAppS3" {
  version = "2012-10-17"
  statement {
    actions = ["s3:PutObject",
      "s3:PutObjectAcl",
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteObject"
    ]
    effect = "Allow"
    resources = ["arn:aws:s3:::webapps31",
                 "arn:aws:s3:::webapps31/*"]
  }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

provider "aws" {
    profile = "dev2"
    region = var.region
}

resource "aws_vpc" "vpc-1" {
    cidr_block              = "10.0.0.0/16"
    enable_dns_hostnames    = true
    enable_dns_support      = true
    assign_generated_ipv6_cidr_block = false
}
resource "aws_subnet" "subnet-1" {
    cidr_block              = "10.0.1.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az1
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-1"
    }
}

resource "aws_subnet" "subnet-2" {
    cidr_block              = "10.0.2.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az2
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-2"
    }
}

resource "aws_subnet" "subnet-3" {
    cidr_block              = "10.0.3.0/24"
    vpc_id                  = aws_vpc.vpc-1.id
    availability_zone       = var.az3
    map_public_ip_on_launch = true
    tags = {
        Name = "csye6225-subnet-3"
    }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc-1.id
}

resource "aws_route" "r" {
    route_table_id = aws_vpc.vpc-1.default_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
resource "aws_route_table" "routetable" {
    vpc_id = aws_vpc.vpc-1.id
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
      Name = "Main"
    }
  }
  resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.routetable.id
  }
  resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.subnet-2.id
    route_table_id = aws_route_table.routetable.id
  }
  resource "aws_route_table_association" "c" {
    subnet_id = aws_subnet.subnet-3.id
    route_table_id = aws_route_table.routetable.id
  }

resource "aws_security_group" "ec2" {
  name        = "ec2"
  vpc_id      = aws_vpc.vpc-1.id
  description = "EC2 Security group"
  

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "DB" {
  name        = "DB"
  description = "RDS Security group"
  vpc_id      = aws_vpc.vpc-1.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_s3_bucket" "bucket" {
  bucket = "webapps31"
  force_destroy  = true
  acl = "private"
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }
    lifecycle_rule {
    prefix  = "config/"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}
resource "aws_db_subnet_group" "dbsubnet" {
  name = "dbsubnet"
  subnet_ids = [aws_subnet.subnet-1.id,aws_subnet.subnet-2.id]
}
resource "aws_db_instance" "webappdb" {

  engine               = "mysql"
  engine_version       = "8.0.21"
  instance_class       = "db.t3.micro"
  name                 = var.dbname
  username             = var.dbusername
  password             = var.dbpassword
  multi_az             = "false"
  identifier           =  "csye6225-f20"
  db_subnet_group_name =  aws_db_subnet_group.dbsubnet.name
  publicly_accessible    =  "false"
  vpc_security_group_ids = [aws_security_group.DB.id]
  skip_final_snapshot = true
  final_snapshot_identifier = "webappdbsnapshot"
  allocated_storage = 20
}

resource "aws_instance" "webapp" {

  ami           = var.amiID
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet-1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data = "user = root, password = liukeyu521,host = csye6225-f20.cp8alz277zmq.us-east-1.rds.amazonaws.com,bucketname = webapps31"


  root_block_device {
    volume_size = 20
    volume_type = "gp2"
    delete_on_termination = true
  }

  key_name = "CSYE-6225"
  associate_public_ip_address = true
  depends_on = [aws_db_instance.webappdb]
  iam_instance_profile = aws_iam_instance_profile.profile1.name

  tags = {
    Name = "CodeDeployInstance"
  }

}

resource "aws_iam_policy" "WebAppS3" {
  name = "WebAppS3"
  policy = data.aws_iam_policy_document.WebAppS3.json
}
resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = "CodeDeployEC2ServiceRole"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
}

resource "aws_iam_policy_attachment" "attach" {
  name = "attach-test"
  policy_arn = aws_iam_policy.WebAppS3.arn
  roles = [aws_iam_role.EC2-CSYE6225.name]
}
resource "aws_iam_policy_attachment" "attach1" {
  name = "attach-test1"
  policy_arn = aws_iam_policy.CodeDeploy-EC2-S3.arn
  roles = [aws_iam_role.CodeDeployEC2ServiceRole.name]
}

resource "aws_iam_instance_profile" "profile" {
  name = "test-profile"
  role = aws_iam_role.EC2-CSYE6225.name
}
resource "aws_iam_instance_profile" "profile1" {
  name = "CodeDeployEC2ServiceRole"
  role = aws_iam_role.CodeDeployEC2ServiceRole.name
}

resource "aws_iam_user_policy" "GH-Upload-To-S3" {
  name = "GH-Upload-To-S3"
  user = var.aws_user
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::codedeploy.6225csyekeyuliu.me",
                "arn:aws:s3:::codedeploy.6225csyekeyuliu.me/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name        = "CodeDeploy-EC2-S3"
  path        = "/"
  description = "CodeDeploy-EC2-S3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [            
                 "*"
            ]
        }
    ]
}
EOF
} 

resource "aws_iam_user_policy" "CodeDeploy-EC2-S3" {
  name = "CodeDeploy-EC2-S3"
  user = var.aws_user
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [            
                 "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_user_policy" "GH-Code-Deploy" {
  name = "GH-Code-Deploy"
  user = var.aws_user
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        { 
            "Effect": "Allow",
            "Action": [
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:GetApplicationRevision"
            ],
            "Resource": [
                  "arn:aws:codedeploy:us-east-1:067131228180:application:csye6225-webapp"
            ]
        },
        { 
            "Effect": "Allow",
            "Action": [
                "codedeploy:CreateDeployment",
                "codedeploy:GetDeployment"
            ],
            "Resource": [
                "*"
            ]
        },
        { 
            "Effect": "Allow",
            "Action": [
                "codedeploy:GetDeploymentConfig"
            ],
            "Resource": [
                "arn:aws:codedeploy:us-east-1:067131228180:deploymentconfig:CodeDeployDefault.OneAtATime",
                "arn:aws:codedeploy:us-east-1:067131228180:deploymentconfig:CodeDeployDefault.HalfAtATime",
                "arn:aws:codedeploy:us-east-1:067131228180:deploymentconfig:CodeDeployDefault.AllAtOnce"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "AWSCodeDeployRole" {
  name = "AWSCodeDeployRole"
  role = aws_iam_role.CodeDeployServiceRole.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:CompleteLifecycleAction",
                "autoscaling:DeleteLifecycleHook",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLifecycleHooks",
                "autoscaling:PutLifecycleHook",
                "autoscaling:RecordLifecycleActionHeartbeat",
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:EnableMetricsCollection",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribePolicies",
                "autoscaling:DescribeScheduledActions",
                "autoscaling:DescribeNotificationConfigurations",
                "autoscaling:DescribeLifecycleHooks",
                "autoscaling:SuspendProcesses",
                "autoscaling:ResumeProcesses",
                "autoscaling:AttachLoadBalancers",
                "autoscaling:AttachLoadBalancerTargetGroups",
                "autoscaling:PutScalingPolicy",
                "autoscaling:PutScheduledUpdateGroupAction",
                "autoscaling:PutNotificationConfiguration",
                "autoscaling:PutLifecycleHook",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DeleteAutoScalingGroup",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:TerminateInstances",
                "tag:GetResources",
                "sns:Publish",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:PutMetricAlarm",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeInstanceHealth",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Resource": "*"
        }
    ]
  }
  EOF
}

resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}