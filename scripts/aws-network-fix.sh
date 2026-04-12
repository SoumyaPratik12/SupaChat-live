#!/bin/bash
# ============================================================================
# AWS NETWORKING FIX SCRIPT
# Fixes: Internet Gateway, Route Table, Security Group for SupaChat on EC2
#
# Usage:
#   bash scripts/aws-network-fix.sh <EC2_PUBLIC_IP>
#
# Prerequisites:
#   - AWS CLI installed and configured (aws configure)
#   - IAM permissions: EC2 describe + modify
# ============================================================================

set -e

EC2_IP="${1:-}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

echo "============================================"
echo " SupaChat AWS Networking Diagnostic & Fix"
echo "============================================"
echo ""

# ── Validate AWS CLI ──────────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  fail "AWS CLI not installed. Install: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  fail "AWS CLI not configured. Run: aws configure"
  exit 1
fi
ok "AWS CLI authenticated"

# ── Find EC2 instance ─────────────────────────────────────────────────────────
if [ -z "$EC2_IP" ]; then
  warn "No IP provided. Listing running instances..."
  aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]" \
    --output table
  echo ""
  read -p "Enter your EC2 public IP: " EC2_IP
fi

info "Looking up instance for IP: $EC2_IP"
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=ip-address,Values=$EC2_IP" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  fail "No running instance found with IP $EC2_IP"
  echo "  Check: aws ec2 describe-instances --filters Name=ip-address,Values=$EC2_IP"
  exit 1
fi
ok "Found instance: $INSTANCE_ID"

# ── Get VPC and subnet ────────────────────────────────────────────────────────
VPC_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].VpcId" --output text)

SUBNET_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SubnetId" --output text)

SG_IDS=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].SecurityGroups[*].GroupId" \
  --output text)

info "VPC:    $VPC_ID"
info "Subnet: $SUBNET_ID"
info "SGs:    $SG_IDS"
echo ""

# ── Check / fix Internet Gateway ──────────────────────────────────────────────
echo "[ Internet Gateway ]"
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || echo "None")

if [ "$IGW_ID" = "None" ] || [ -z "$IGW_ID" ]; then
  warn "No Internet Gateway attached to VPC $VPC_ID — creating one..."
  IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=supachat-igw}]" \
    --query "InternetGateway.InternetGatewayId" --output text)
  aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
  ok "Created and attached Internet Gateway: $IGW_ID"
else
  ok "Internet Gateway exists: $IGW_ID"
fi

# ── Check / fix Route Table ───────────────────────────────────────────────────
echo ""
echo "[ Route Table ]"
RT_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
  --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || echo "None")

if [ "$RT_ID" = "None" ] || [ -z "$RT_ID" ]; then
  # Use main route table for the VPC
  RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
    --query "RouteTables[0].RouteTableId" --output text)
  info "Using main route table: $RT_ID"
fi

# Check if 0.0.0.0/0 → IGW route exists
DEFAULT_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids "$RT_ID" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text 2>/dev/null || echo "")

if [ -z "$DEFAULT_ROUTE" ] || [ "$DEFAULT_ROUTE" = "None" ]; then
  warn "Missing default route 0.0.0.0/0 → IGW — adding..."
  aws ec2 create-route \
    --route-table-id "$RT_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$IGW_ID" || \
  aws ec2 replace-route \
    --route-table-id "$RT_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$IGW_ID"
  ok "Added route: 0.0.0.0/0 → $IGW_ID"
elif echo "$DEFAULT_ROUTE" | grep -q "igw-"; then
  ok "Default route exists: 0.0.0.0/0 → $DEFAULT_ROUTE"
else
  warn "Default route points to $DEFAULT_ROUTE (not an IGW) — replacing..."
  aws ec2 replace-route \
    --route-table-id "$RT_ID" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "$IGW_ID"
  ok "Replaced route: 0.0.0.0/0 → $IGW_ID"
fi

# ── Check subnet auto-assign public IP ───────────────────────────────────────
echo ""
echo "[ Subnet Public IP ]"
AUTO_ASSIGN=$(aws ec2 describe-subnets \
  --subnet-ids "$SUBNET_ID" \
  --query "Subnets[0].MapPublicIpOnLaunch" --output text)

if [ "$AUTO_ASSIGN" != "true" ]; then
  warn "Subnet does not auto-assign public IPs — enabling..."
  aws ec2 modify-subnet-attribute \
    --subnet-id "$SUBNET_ID" \
    --map-public-ip-on-launch
  ok "Enabled auto-assign public IP on subnet"
else
  ok "Subnet auto-assigns public IPs"
fi

# ── Check / fix Security Group rules ─────────────────────────────────────────
echo ""
echo "[ Security Group Rules ]"

REQUIRED_PORTS=(22 80 443 3001 9090)
REQUIRED_NAMES=("SSH" "HTTP (app)" "HTTPS" "Grafana" "Prometheus")

for SG_ID in $SG_IDS; do
  info "Checking SG: $SG_ID"
  for i in "${!REQUIRED_PORTS[@]}"; do
    PORT="${REQUIRED_PORTS[$i]}"
    NAME="${REQUIRED_NAMES[$i]}"

    EXISTS=$(aws ec2 describe-security-groups \
      --group-ids "$SG_ID" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`$PORT\` && ToPort==\`$PORT\` && IpProtocol=='tcp'].IpRanges[?CidrIp=='0.0.0.0/0'].CidrIp" \
      --output text 2>/dev/null || echo "")

    if [ -z "$EXISTS" ]; then
      warn "Port $PORT ($NAME) not open — adding inbound rule..."
      aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port "$PORT" \
        --cidr "0.0.0.0/0" \
        --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=supachat-$PORT}]" \
        2>/dev/null || warn "Rule for port $PORT may already exist (skipping)"
      ok "Opened port $PORT ($NAME)"
    else
      ok "Port $PORT ($NAME) already open"
    fi
  done
done

# ── Final connectivity test ───────────────────────────────────────────────────
echo ""
echo "[ Connectivity Test ]"
sleep 3

if curl -sf --connect-timeout 10 "http://$EC2_IP/health" &>/dev/null; then
  ok "http://$EC2_IP/health → reachable ✅"
else
  warn "http://$EC2_IP/health → not yet reachable"
  echo ""
  echo "  If still unreachable after this fix, check:"
  echo "  1. EC2 instance is in a PUBLIC subnet (not private)"
  echo "  2. Instance has a public IP assigned (not just private)"
  echo "  3. Docker containers are running: ssh ubuntu@$EC2_IP 'docker ps'"
  echo "  4. Nginx is bound to 0.0.0.0:80 (not 127.0.0.1:80)"
fi

echo ""
echo "============================================"
echo " Fix complete. Access your app:"
echo "   App:        http://$EC2_IP"
echo "   Grafana:    http://$EC2_IP:3001  (admin/admin)"
echo "   Prometheus: http://$EC2_IP:9090"
echo "   API Docs:   http://$EC2_IP/api/docs"
echo "============================================"
