provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example1" {
  ami = "ami-002068ed284fb165b"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-test"
  }
}