output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.private_db[*].id
}

output "asg_name" {
  value = aws_autoscaling_group.web.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "site_url" {
  description = "URL to reach the application"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_cloudfront_distribution.main.domain_name}"
}
