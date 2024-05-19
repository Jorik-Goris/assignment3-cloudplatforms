
// de juiste provider (aws) en versie instellen
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49"
    }
  }
}

// de regio instellen waarin we onze infrastructuur willen aanmaken
provider "aws" {
  region = "us-east-1"

}

// VPC provisioning
// hier wordt de VPC "main" aangemaakt met de 10.0.0.0/16 CIDR range. DNS wordt aangezet voor de resources binnen deze VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "assignment3-jg-vpc"
  }

}


// het eerste public subnet in onze main vpc wordt aangemaakt met subnet 10.0.0.0/24, deze wordt aangemaakt in de us-east-1a AZ en krijgt een publiek adres. In deze public subnets zal onze ALB en NAT gateway gedeployed worden.
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_2"
  }
}

// hier worden de private subnets aangemaakt. Deze staan afwisselend in us-east-1a of us-east-1. De services die hier gedeployed worden (ALB en RDS) vereisen subnets in verschillende AZ's 
// Private subnet 1 & 2 zullen internet access krijgen via de NAT gateway, om bv. de image van de ECR te pullen, private 3 en 4 bevatten de database en hebben geen internet access
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet_2"
  }
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet_3"
  }
}

resource "aws_subnet" "private_subnet_4" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet_4"
  }
}

// hier wordt een internet gateway geprovisioned in onze VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

//hier wordt een NAT gateway geprovisioned in onze VPC
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

// creeert een elastic IP in onze VPC, niet meteen nodig
resource "aws_eip" "nat" {
  vpc = true
}


// hier wordt de public route table aangemaakt (zie diagram)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}


// hier wordt de private route table aangemaakt voor het private 1 subnet
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}


// hier wordt de private route table aangemaakt voor het private 2 subnet
resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}


// deze route tables worden geassociate met de juiste subnets
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_2.id
}

// database provisioning
// hier wordt een security group aangemaakt die poort 3306 zal toelaten op onze RDS database
resource "aws_security_group" "db" {
  name_prefix = "db-"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
// hier wordt een subnetgroup voor onze RDS aangemaakt met private 3 en private 4, de 2 private subnets zonder internet access in verschillende AZ's
resource "aws_db_subnet_group" "private_subnet_group" {
  name       = "private-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_3.id, aws_subnet.private_subnet_4.id]  
}

// hier wordt de database zelf aangemaakt, met de juiste engine/versie, username/password, voorheen vermelde subnet group en security group, alsook opties om de free version te matchen
// db.t3.micro en 20 gig storage
resource "aws_db_instance" "flaskappdatabase" {
  engine                 = "mysql"
  engine_version         = "8.0.35"
  db_subnet_group_name   = aws_db_subnet_group.private_subnet_group.name 
  db_name                = "appdatabase"
  identifier             = "db"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  publicly_accessible    = false
  username               = "admin"
  password               = "password"
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true


  tags = {
    Name = "backend-db-flaskapp"
  }
}

// ALB Security Group
// security group voor onze ALB die poort 80 zal open stellen. Dit is het 'ingangspunt' van onze architectuur, waar HTTP traffic op zal binnen komen
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
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

// ALB
// hier wordt de ALB zelf aangemaakt in de public 1 en public 2 subnets. Deze is van het type application en is external (open gesteld aan het internet)
resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "my-alb"
  }
}

// ALB Target Group
// Onze ALB heeft een target group nodig, dit zal onze Fargate cluster zijn
// de target group luistert op poort 5000 en is van het type IP
resource "aws_lb_target_group" "alb_tg" {
  name     = "my-alb-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

// ALB Listener
// de listener zal luisteren op poort 80 voor requists en deze forwarden naar onze target group
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

// dit maakt een ecs cluster aan met de naam cluster_jorik
resource "aws_ecs_cluster" "cluster_jorik" {
  name = "cluster_jorik"
}

// security group om aan onze service toe te wijzen die onze container zal exposen op poort 5000
resource "aws_security_group" "flask" {
  name_prefix = "flask-"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


