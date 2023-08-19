terraform {
  required_version = ">= 0.14"

  # Provider configuration can also be specified within the `terraform` block
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
       # access_key = "AKIAYISCODDGRHABWCHV"
       # secret_key = "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"
       # region     = "us-east-1"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}

#Creating VPC
resource "aws_vpc" "TerraformVPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "TFVPC"
  }
}
#Creating Public Subnet 
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.TerraformVPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet"
  }
}
#Creating Private Subnet 
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.TerraformVPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet"
  }
}
#Creating Private db Subnet 
resource "aws_subnet" "private_db_subnet" {
  vpc_id            = aws_vpc.TerraformVPC.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "private_db_subnet"
  }
}
#Created Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.TerraformVPC.id

  tags = {
    Name = "TFigw"
  }
}
#Creating Route Table for public subnet
resource "aws_route_table" "public_routeTable" {
  vpc_id = aws_vpc.TerraformVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_routeTable"
  }
}
#Associating Public Route Table with public subnet
resource "aws_route_table_association" "PublicRTassociation" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_routeTable.id
}
#Elastic IP
resource "aws_eip" "elasticIP" {
   vpc   = true
 }


#Creating NAT Gateway
resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.elasticIP.id
   subnet_id = aws_subnet.public_subnet.id
 }
#Creating Route Table for private subnet
resource "aws_route_table" "private_routeTable" {
  vpc_id = aws_vpc.TerraformVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NATgw.id
  }

  tags = {
    Name = "private_routeTable"
  }
}
#Associating Public Route Table with private subnet
resource "aws_route_table_association" "PrivateRTassociation" {

  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_routeTable.id
}
#Creating Route Table for private db subnet
resource "aws_route_table" "private_db_routeTable" {
  vpc_id = aws_vpc.TerraformVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NATgw.id
  }

  tags = {
    Name = "private_db_routeTable"
  }
}
#Associating Public Route Table with private db subnet
resource "aws_route_table_association" "PrivatedbRTassociation" {

  subnet_id      = aws_subnet.private_db_subnet.id
  route_table_id = aws_route_table.private_db_routeTable.id
}
#creating security group for web server
resource "aws_security_group" "webserver_sg" {
  name        = "webserver_sg"
  description = "Allow SSH inbound connections"
  vpc_id = aws_vpc.TerraformVPC.id
  
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

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webserver_sg"
  }
}
#Creating Key Pair
resource "aws_key_pair" "InfraKey" {
  key_name   = "InfraKey"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "InfraKey" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "InfraKey"
}

#creating webserver instance
resource "aws_instance" "webserver" {
  ami           = "ami-0e47f4c3e9beeff63"
  instance_type = "t2.micro"
  key_name = "InfraKey"
  vpc_security_group_ids = [ aws_security_group.webserver_sg.id ]
  subnet_id = aws_subnet.public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name = "webserver"
  }
}
#creating security group for backend instance
resource "aws_security_group" "appserver_sg" {
  name        = "appserver_sg"
  description = "Allow SSH inbound connections"
  vpc_id = aws_vpc.TerraformVPC.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "appserver_sg"
  }
}
#creating Private Instance
resource "aws_instance" "appserver_instance" {
  ami           = "ami-0f94c0f98151e86d7"
  instance_type = "t2.micro"
  key_name = "InfraKey"
  vpc_security_group_ids = [ aws_security_group.appserver_sg.id ]
  subnet_id = aws_subnet.private_subnet.id
  associate_public_ip_address = false

  tags = {
    Name = "appserver"
  }
}
#create a security group for RDS Database Instance
resource "aws_security_group" "rds_sg" {
  name = "rds_sg"
  vpc_id = aws_vpc.TerraformVPC.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#creating Private db Instance
resource "aws_instance" "private_db_instance" {
  ami           = "ami-04ba290e683b98c02"
  instance_type = "t2.micro"
  key_name = "InfraKey"
  vpc_security_group_ids = [ aws_security_group.appserver_sg.id ]
  subnet_id = aws_subnet.private_db_subnet.id
  associate_public_ip_address = false

  tags = {
    Name = "dbserver"
  }
}
# #creating db_instance
# resource "aws_db_instance" "default" {
#   allocated_storage    = 10
#   db_name              = "mydb"
#   identifier           = "myrdsinstance"
#   engine               = "mysql"
#   storage_type         = "gp2"
#   instance_class       = "db.t2.micro"
#   username             = "admin"
#   password             = "redhat123"
#   parameter_group_name = "default.mysql5.7"
#   vpc_security_group_ids = aws_security_group.rds_sg.id
#   skip_final_snapshot  = true
# }
# db_subnet_group_name = aws_db_subnet_group.db-subnet.name
