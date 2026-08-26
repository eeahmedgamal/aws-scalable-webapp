"""
Regenerates docs/architecture-diagram.png from source.
Run: python3 generate_diagram.py
Requires: pip install graphviz  (and the system 'dot' binary, e.g. apt install graphviz)
"""
import graphviz

g = graphviz.Digraph("architecture", format="png")
g.attr(rankdir="TB", fontname="Helvetica", fontsize="11", bgcolor="white", splines="ortho")
g.attr("node", fontname="Helvetica", fontsize="11", shape="box", style="rounded,filled")

# --- External layer ---
g.node("users", "Internet users", fillcolor="#F1EFE8", color="#5F5E5A")
g.node("route53", "Route 53\nDNS routing + health checks", fillcolor="#F1EFE8", color="#5F5E5A")
g.node("cloudfront", "CloudFront\nEdge caching", fillcolor="#E6F1FB", color="#185FA5")

g.edge("users", "route53")
g.edge("route53", "cloudfront")

with g.subgraph(name="cluster_vpc") as vpc:
    vpc.attr(label="VPC 10.0.0.0/16", style="rounded", color="#0F6E56", fontcolor="#0F6E56", fontsize="12")

    vpc.node("alb", "ALB + WAF\nLayer 7 routing, OWASP rules", fillcolor="#FAECE7", color="#993C1D")

    with vpc.subgraph(name="cluster_aza") as aza:
        aza.attr(label="Availability Zone A", style="dashed", color="#888780")
        aza.node("nat_a", "Public subnet\nNAT Gateway", fillcolor="#FAECE7", color="#993C1D")
        aza.node("ec2_a", "Private subnet\nEC2 in Auto Scaling Group", fillcolor="#EEEDFE", color="#534AB7")
        aza.node("rds_a", "RDS primary\nMulti-AZ database", fillcolor="#FBEAF0", color="#993556")

    with vpc.subgraph(name="cluster_azb") as azb:
        azb.attr(label="Availability Zone B", style="dashed", color="#888780")
        azb.node("nat_b", "Public subnet\nNAT Gateway", fillcolor="#FAECE7", color="#993C1D")
        azb.node("ec2_b", "Private subnet\nEC2 in Auto Scaling Group", fillcolor="#EEEDFE", color="#534AB7")
        azb.node("rds_b", "RDS standby\nAutomatic failover", fillcolor="#FBEAF0", color="#993556")

    vpc.edge("alb", "ec2_a")
    vpc.edge("alb", "ec2_b")
    vpc.edge("ec2_a", "rds_a")
    vpc.edge("ec2_b", "rds_a", style="invis")  # keep layout tidy
    vpc.edge("rds_a", "rds_b", label="sync replication", dir="both", color="#993556", fontsize="9")

g.edge("cloudfront", "alb")

g.node("cw", "CloudWatch + SNS\nMonitoring and alerts", fillcolor="#F1EFE8", color="#5F5E5A")
g.edge("alb", "cw", style="dashed")
g.edge("ec2_a", "cw", style="dashed")
g.edge("ec2_b", "cw", style="dashed")

g.render("architecture-diagram", cleanup=True)
print("Wrote architecture-diagram.png")
