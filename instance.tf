resource "aws_key_pair" "demo_key" {
  key_name   = "MyKeyPair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

resource "aws_instance" "jenkins-cli-wildfly" {
  ami           = var.ami
  instance_type = "t2.small"
  key_name      = aws_key_pair.demo_key.key_name 
  
  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.ssh.id}",
    "${aws_security_group.egress-tls.id}",
    "${aws_security_group.ping-ICMP.id}",
	"${aws_security_group.web_server.id}"
  ]
  
  provisioner "file" {
    source      = "binaries/helloworldjsf22.war"
    destination = "myApp.war"
  }
  
  provisioner "file" {
    source      = "server/jboss-eap-7.1.zip"
    destination = "jboss-eap-7.1.zip"
  }
  
  provisioner "file" {
    source      = "server/apache-tomcat-9.0.22.zip"
    destination = "apache-tomcat-9.0.22.zip"
  }
  
  #Java install
  provisioner "remote-exec" {
    inline = [
	  "sudo apt-get -y update",
      "sudo apt-get -y install openjdk-8-jdk",
	  "JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64",
	  "PATH=$PATH:$HOME/bin:$JAVA_HOME/bin",
      "export JAVA_HOME",
      "export JRE_HOME",
      "export PATH",
	  "sudo apt-get install unzip -y",
    ]
  }
  
  #Jboss eap install
  provisioner "remote-exec" {     
    inline = [
		"sudo mkdir /opt/jboss/",
		"sudo mv jboss-eap-7.1.zip /opt/jboss/",
		"cd /opt/jboss/",
		"sudo unzip jboss-eap-7.1.zip",
	]   
  }
  
  #Tomcat 9 install
  provisioner "remote-exec" {     
    inline = [
		"sudo mkdir /opt/tomcat/",
		"sudo mv apache-tomcat-9.0.22.zip /opt/tomcat/",
		"cd /opt/tomcat/",
		"sudo unzip apache-tomcat-9.0.22.zip",
	]   
  }
  
  #deploy jenkins
  provisioner "remote-exec" {
	inline = [
		"sudo wget http://mirrors.jenkins.io/war-stable/latest/jenkins.war",
		"sudo mv /home/ubuntu/jenkins.war /opt/tomcat/apache-tomcat-9.0.22/webapps/jenkins.war",
		"sudo chmod +x /opt/tomcat/apache-tomcat-9.0.22/bin/catalina.sh",
		"sudo bash /opt/tomcat/apache-tomcat-9.0.22/bin/startup.sh"
	]
  }
  
  tags = {
    Name     = "jenkins-cli-wildfly"
    Batch    = "7AM"
    Location = "US"
  }
  
  
  connection {
    host        = coalesce(self.public_ip, self.private_ip)
    type        = "ssh"
    user        = var.INSTANCE_USERNAME
    private_key = file(var.PATH_TO_PRIVATE_KEY)
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
    from_port   = 85
    to_port     = 85
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
  
  ingress {
    from_port   = 8585
    to_port     = 8585
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_server-example-default-vpc"
  }
}

output "app-jboss-url" {
  value = "http://${aws_instance.jenkins-cli-wildfly.public_ip}:8080"
}

output "jenkins-tomcat-url" {
  value = "http://${aws_instance.jenkins-cli-wildfly.public_ip}:8585/jenkins"
}