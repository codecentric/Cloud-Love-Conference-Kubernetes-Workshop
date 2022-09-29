resource "aws_instance" "ssh" {
  ami = "ami-065deacbcaac64cf2"
  instance_type = "t3.large"
  key_name = aws_key_pair.kp.key_name
  security_groups = [aws_security_group.ingress-all-test.id]
  subnet_id = aws_subnet.subnet-uno.id

  user_data = <<-EOL
  #!/bin/bash

  %{for user in kubernetes_service_account.user-account}
  adduser --disabled-password --gecos "" ${user.metadata[0].name}
  echo ${user.metadata[0].name}:${user.metadata[0].name} | chpasswd

  echo "Match User ${user.metadata[0].name}" >> /etc/ssh/sshd_config
  echo "  PasswordAuthentication yes" >> /etc/ssh/sshd_config

  %{ endfor }
  service ssh restart

  snap install kubectl --classic

  echo "${base64decode(module.eks.cluster_certificate_authority_data)}" > ca-file

  %{for user in data.kubernetes_secret.user-secret}

  kubectl config set-cluster cluster --server=${module.eks.cluster_endpoint} --embed-certs=true --certificate-authority=ca-file --kubeconfig=/home/${user.metadata[0].namespace}/.kube/config
  kubectl config set-credentials ${user.metadata[0].namespace} --token=${user.data["token"]} --kubeconfig=/home/${user.metadata[0].namespace}/.kube/config
  kubectl config set-context ${user.metadata[0].namespace} --cluster=cluster --user=${user.metadata[0].namespace} --namespace=${user.metadata[0].namespace} --kubeconfig=/home/${user.metadata[0].namespace}/.kube/config
  kubectl config use-context ${user.metadata[0].namespace} --kubeconfig=/home/${user.metadata[0].namespace}/.kube/config

  chown ${user.metadata[0].namespace} /home/${user.metadata[0].namespace}/.kube/config

  %{ endfor }

  EOL
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh
  provisioner "local-exec" { # Create "myKey.pem" to your computer!
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