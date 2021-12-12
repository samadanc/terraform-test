provider "aws" {
  region = "us-east-2"
}

variable "server_port" {
  description = "the port the server will use for HTTP requests"
  default = 8080
}

variable "elb_port" {
  description = "the port the elb will use to route to correct port for instances"
  default = 80
}

resource "aws_security_group" "instance" {
  name = "terraform-test-instance"

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  ingress {
    from_port = "${var.elb_port}"
    to_port = "${var.elb_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example1" {
  ami = "ami-002068ed284fb165b"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd - f -d "${var.server_port}" &
              EOF

//  tags = {
//    Name = "terraform-example1"
//  }
}

resource "aws_launch_configuration" "example2" {
  image_id = "ami-002068ed284fb165b"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd - f -d "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "example3" {
  max_size = 10
  min_size = 2
  launch_configuration = "${aws_launch_configuration.example2.id}"
  availability_zones = "${data.aws_availability_zones.all.names}"

  load_balancers = ["${aws_elb.example4.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    propagate_at_launch = true
    value = "terraform-asg-example"
  }
}

resource "aws_elb" "example4" {
  name = "terraform-example-elb"
  availability_zones = "${data.aws_availability_zones.all.names}"
  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    instance_port = "${var.server_port}"
    instance_protocol = "http"
    lb_port = "${var.elb_port}"
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    interval = 30
    target = "HTTP:${var.server_port}/"
    timeout = 3
    unhealthy_threshold = 2
  }
}

//output "public_ip" {
//  value = "${aws_instance.example1.public_ip}"
//}

output "elb_dns_name" {
  value = "${aws_elb.example4.dns_name}"
}