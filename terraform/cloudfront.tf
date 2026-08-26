resource "aws_cloudfront_distribution" "main" {
  count = var.enable_cloudfront ? 1 : 0

  enabled     = true
  comment     = "${var.project_name} CDN in front of the ALB"
  price_class = "PriceClass_100"

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port              = 443
      origin_protocol_policy  = "http-only" # ALB listener 80 above; switch to https-only once ACM cert + listener 443 are in place
      origin_ssl_protocols    = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress                = true

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400  # 1 day for static assets
    max_ttl     = 604800 # 7 days
  }

  # Do not cache dynamic API/health-check paths
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == "" ? true : null
    acm_certificate_arn            = var.domain_name != "" ? aws_acm_certificate_validation.cloudfront[0].certificate_arn : null
    ssl_support_method             = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  aliases = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []

  tags = merge(local.common_tags, { Name = "${var.project_name}-cdn" })
}
