
provider "aws" {
  region  = "us-east-1"
  version = "3.61.0"
}

resource "aws_instance" "M1" {
ami = "ami-0b0ea68c435eb488d"
instance_type = "t2.micro"
}


resource "aws_instance" "M2" {
ami = "ami-0b0ea68c435eb488d"
instance_type = "t2.micro"
vpc_security_group_ids = [aws_security_group.instance.id]
user_data = <<-EOF
#!/bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &
EOF
}

resource "aws_security_group" "instance" {
name = "terraform-example-instance"
ingress {
from_port = 8080
to_port = 8080
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}


resource "aws_lb" "example" {
name = "terraform-asg-example"
load_balancer_type = "application"
subnets = data.aws_subnet_ids.default.ids
security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
load_balancer_arn = aws_lb.example.arn
port = 80
protocol = "HTTP"
# By default, return a simple 404 page
default_action {
type = "fixed-response"
fixed_response {
content_type = "text/plain"
message_body = "404: page not found"
status_code = 404
}
}
}

resource "aws_security_group" "alb" {
name = "terraform-example-alb"
# Allow inbound HTTP requests
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
# Allow all outbound requests
egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_lb_target_group" "asg" {
name = "terraform-asg-example"
port = var.server_port
protocol = "HTTP"
vpc_id = data.aws_vpc.default.id
health_check {
path = "/"
protocol = "HTTP"
matcher = "200"
interval = 15
timeout = 3
healthy_threshold = 2
unhealthy_threshold = 2
}
}

resource "aws_lb_listener_rule" "asg" {
listener_arn = aws_lb_listener.http.arn
priority = 100
condition {
field = "path-pattern"
values = ["*"]
}
action {
type = "forward"
target_group_arn = aws_lb_target_group.asg.arn
}
}

# ASG
resource "aws_lb_target_group" "asg" {
name = "terraform-asg-example"
port = var.server_port
protocol = "HTTP"
vpc_id = data.aws_vpc.default.id
health_check {
path = "/"
protocol = "HTTP"
matcher = "200"
interval = 15
timeout = 3
healthy_threshold = 2
unhealthy_threshold = 2
}
}

resource "aws_autoscaling_group" "example" {
launch_configuration = aws_launch_configuration.example.name
vpc_zone_identifier = data.aws_subnet_ids.default.ids
min_size = 2
max_size = 10
tag {
key = "Name"
value = "terraform-asg-example"
propagate_at_launch = true
}
}