resource "aws_key_pair" "demo_key" {
  key_name   = "MyKeyPair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

/*
resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16" # Defines overall VPC address space
  enable_dns_hostnames = true          # Enable DNS hostnames for this VPC
  enable_dns_support   = true          # Enable DNS resolving support for this VPC
  instance_tenancy     = "default"
  enable_classiclink   = "false"
  tags {
    Name = "VPC-my-vpc" # Tag VPC with name
  }
}
*/

resource "aws_instance" "jenkins-ci" {
  count = "${var.instance_count}"

  #ami = "${lookup(var.amis,var.region)}"
  ami           = "${var.ami}"
  instance_type = "${var.instance}"
  key_name      = "${aws_key_pair.demo_key.key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.egress-tls.id}",
    "${aws_security_group.ping-ICMP.id}",
	"${aws_security_group.web_server.id}"
  ]


  ebs_block_device {
    device_name           = "/dev/sdg"
    volume_size           = 500
    volume_type           = "io1"
    iops                  = 2000
    encrypted             = true
    delete_on_termination = true
  }
  
  provisioner "remote-exec" {     
    inline = [       
      "cd /home/ubuntu",
      "sudo mkdir tmp",
      "sudo chmod -R a+rwx /home/ubuntu/tmp",            
    ]   
  }
  
  provisioner "file" {
    source      = "templates/install_jenkins.sh"
    destination = "/home/ubuntu/tmp/install_jenkins.sh"
  }
  
  #Java install
  provisioner "remote-exec" {
    inline = [
	  "sudo apt-get -y update",
      "sudo apt-get -y install openjdk-8-jdk",
    ]
  }
  
  #Jenkins Install
  provisioner "remote-exec" {
	inline = [
		"sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'",
		"sudo wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -",
		"sudo apt-get update -y",
		"sudo apt-get install jenkins -y",
		"sudo service jenkins start",
	]
  }

  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    private_key = file(var.PATH_TO_PRIVATE_KEY)
    user        = "${var.ansible_user}"
  }
  
  tags = {
    Name     = "jenkins-ci-${count.index +1 }"
    Batch    = "7AM"
    Location = "US"
  }
}

resource "aws_security_group" "web" {
  name        = "default-web-example"
  description = "Security group for web that allows web traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

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

  tags = {
    Name = "web-example-default-vpc"
  }
}

resource "aws_security_group" "ssh" {
  name        = "default-ssh-example"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-example-default-vpc"
  }
}

resource "aws_security_group" "egress-tls" {
  name        = "default-egress-tls-example"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "egress-tls-example-default-vpc"
  }
}

resource "aws_security_group" "ping-ICMP" {
  name        = "default-ping-example"
  description = "Default security group that allows to ping the instance"
  #vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "ping-ICMP-example-default-vpc"
  }
}

# Allow the web app to receive requests on port 8080
resource "aws_security_group" "web_server" {
  name        = "default-web_server-example"
  description = "Default security group that allows to use port 8080"
  #vpc_id      = "${aws_vpc.my-vpc.id}"
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_server-example-default-vpc"
  }
}

output "url-jenkins" {
  value = "http://${aws_instance.jenkins-ci.0.public_ip}:8080"
}