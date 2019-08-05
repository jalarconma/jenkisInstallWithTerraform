resource "aws_key_pair" "demo_key" {
  key_name   = "MyKeyPair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

resource "aws_instance" "wildfly" {
  ami           = "ami-089210bc871785ac4"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.demo_key.key_name 
  
  provisioner "file" {
    source      = "binaries/helloworldjsf22.war"
    destination = "myApp.war"
  }
  
  provisioner "remote-exec" {     
    inline = [
		"sleep 150",
		"sudo cp myApp.war /opt/bitnami/wildfly/bin/myApp.war",
		"sudo -u wildfly /opt/bitnami/wildfly/bin/jboss-cli.sh --connect --command=\"deploy --force myApp.war\"",
	]   
  }
  
  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = var.INSTANCE_USERNAME
    private_key = file(var.PATH_TO_PRIVATE_KEY)
  }
}

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
  
  provisioner "remote-exec" {     
    inline = [       
      "cd /home/ubuntu",
      "sudo mkdir tmp",
      "sudo chmod -R a+rwx /home/ubuntu/tmp",            
    ]   
  }
  
  provisioner "file" {
    source      = "templates/configure_jenkis.tpl"
    destination = "/home/ubuntu/tmp/configure_jenkins.sh"
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
  
  #Jenkins configuration
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/tmp/configure_jenkins.sh",
      "/home/ubuntu/tmp/configure_jenkins.sh",
    ]
  }
  
  provisioner "file" {
    source      = "mykey"
    destination = "server-app-key"
  }
  
  provisioner "file" {
    source      = "mykey.pub"
    destination = "server-app-key.pub"
  }
  
  provisioner "remote-exec" {
    inline = [
		"sudo mkdir /var/lib/jenkins/.ssh",
		"sudo mv server-app-key /var/lib/jenkins/.ssh/server-app-key",
		"sudo mv server-app-key.pub /var/lib/jenkins/.ssh/server-app-key.pub",
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

output "url-App" {
  value = "http://${aws_instance.wildfly.public_ip}/myApp/index.jsf"
}

output "url-jenkins" {
  value = "http://${aws_instance.jenkins-ci.0.public_ip}:8080"
}