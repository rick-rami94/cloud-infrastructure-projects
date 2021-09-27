# Delaring provider information
provider "aws" {
     region = "<Region that you want to deploy to> "
     access_key = "<AWS Access Key ID>"
     secret_key = "<AWS Secret Key>"
}

# Create a VPC

resource "aws_vpc" "prod_vpc" {
     cidr_block = "10.0.0.0/16"
     tags = {
          Name = "Production"
     }
  
}

# Creating an internet gateway

resource "aws_internet_gateway" "gateway" {
     vpc_id = aws_vpc.prod_vpc.id
}

# Creating a custom routing table 

resource "aws_route_table" "prod_route_table" {
     vpc_id = aws_vpc.prod_vpc.id
     route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.gateway.id
   }
}

# Create a Subnet

resource "aws_subnet" "subnet_1" {
  vpc_id = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    "Name" = "prod-subnet"
  }
}

# Associate subnet with Route Table

resource "aws_route_table_association" "association" {
  subnet_id = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.prod_route_table.id
}

# Create a security group that allows web and ssh traffic

resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id = aws_vpc.prod_vpc.id

     ingress {
          description = "HTTPS"
          from_port = 443
          to_port = 443
          protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }

     ingress {
          description = "HTTP"
          from_port = 80
          to_port = 80
          protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }

     ingress {
          description = "SSH"
          from_port = 22
          to_port = 22
          protocol = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
     }

     tags = {
       "Name" = "allow_web"
     }
}

# create a network interface with IP address in the previously created subnet

resource "aws_network_interface" "web_server_nic" {
  subnet_id = aws_subnet.subnet_1.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP tothe network interface 

resource "aws_eip" "first" {
     vpc = true
     network_interface = aws_network_interface.web_server_nic.id
     associate_with_private_ip = "10.0.1.50"
     depends_on = [
       aws_internet_gateway.gateway
     ]
}

# provide public ip address as output

output "server_public_ip" {
     value = aws_eip.first.public_ip
}

# Creating Ubuntu server and install apache2

resource "aws_instance" "web_server_instance" {
     ami = "ami-00399ec92321828f5"
     instance_type = "t2.micro"
     availability_zone = "us-east-2a"

     network_interface {
       device_index = 0
       network_interface_id = aws_network_interface.web_server_nic.id
     }
     
     user_data = <<-EOF
                    #!/bin/bash
                    sudp apt update -y
                    sudo apt install apache2
                    sudo bash - 'echo Welcome to your web server! > /var/www/html/index.html'
                    EOF
     tags = {
          Name="web_server"
     }
}

output "server_private_ip" {
     value = aws_instance.web_server_instance.private_ip
     }
