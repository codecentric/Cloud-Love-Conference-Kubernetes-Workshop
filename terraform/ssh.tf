resource "aws_instance" "ssh" {
  ami = "ami-065deacbcaac64cf2"
  instance_type = "t2.medium"
  key_name = aws_key_pair.kp.key_name
  security_groups = [aws_security_group.ingress-all-test.id]
  subnet_id = aws_subnet.subnet-uno.id
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./myKey.pem"
  }
}

resource "aws_subnet" "subnet-uno" {
  cidr_block = cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)
  vpc_id = aws_vpc.test-env.id
  availability_zone = "eu-central-1a"
}

resource "aws_vpc" "test-env" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_eip" "ip-test-env" {
  instance = aws_instance.ssh.id
  vpc      = true
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = aws_vpc.test-env.id
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.test-env.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-env-gw.id
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.subnet-uno.id
  route_table_id = aws_route_table.route-table-test-env.id
}

resource "aws_security_group" "ingress-all-test" {
  name = "allow-all-sg"
  vpc_id = aws_vpc.test-env.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "ip" {
  value = aws_eip.ip-test-env.public_ip
}