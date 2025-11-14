#!/bin/bash

echo "=== deSEC Restricted Token Generator ==="

################################################################################
# LOGIN
################################################################################

read -p "Email: " EMAIL
read -s -p "Password: " PASSWORD
echo ""

LOGIN_PAYLOAD=$(jq -c -n --arg email "$EMAIL" --arg password "$PASSWORD" '$ARGS.named')

echo "Logging into deSEC..."

LOGIN_RESPONSE=$(curl -s -X POST https://desec.io/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d "$LOGIN_PAYLOAD")

AUTH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')

if [[ "$AUTH_TOKEN" == "null" || -z "$AUTH_TOKEN" ]]; then
  echo "❌ Login failed:"
  echo "$LOGIN_RESPONSE"
  exit 1
fi

echo "✔ Login successful."


################################################################################
# SINGLE DOMAIN INPUT
################################################################################

read -p "Full domain (example: test.example.com): " FULLDOMAIN

SUBNAME="${FULLDOMAIN%%.*}"
DOMAIN="${FULLDOMAIN#*.}"
TLD="${DOMAIN##*.}"
TOKEN_NAME="${SUBNAME}-${TLD}"

echo ""
echo "Parsed:"
echo "  Subname: $SUBNAME"
echo "  Domain:  $DOMAIN"
echo "  TLD:     $TLD"
echo "  Token:   $TOKEN_NAME"
echo ""


################################################################################
# VALIDATE DOMAIN + SUBDOMAIN EXISTENCE
################################################################################

echo "Checking if domain '$DOMAIN' exists..."

DOMAIN_LIST=$(curl -s -X GET https://desec.io/api/v1/domains/ \
  -H "Authorization: Token $AUTH_TOKEN")

DOMAIN_EXISTS=$(echo "$DOMAIN_LIST" | jq -r --arg d "$DOMAIN" '.[] | select(.name == $d)')

if [[ -z "$DOMAIN_EXISTS" ]]; then
  echo "❌ ERROR: Domain '$DOMAIN' not found."
  echo "Available domains:"
  echo "$DOMAIN_LIST" | jq -r '.[].name'
  exit 1
fi

echo "✔ Domain exists."


echo "Checking if subdomain '$SUBNAME.$DOMAIN' exists..."

RRSETS=$(curl -s -X GET https://desec.io/api/v1/domains/"$DOMAIN"/rrsets/ \
  -H "Authorization: Token $AUTH_TOKEN")

SUB_EXISTS=$(echo "$RRSETS" | jq -r --arg s "$SUBNAME" '.[] | select(.subname == $s)')

if [[ -z "$SUB_EXISTS" ]]; then
  echo "❌ ERROR: Subdomain '$SUBNAME.$DOMAIN' does NOT exist."
  echo "Create at least one RRset (A or AAAA) before generating a restricted token."
  exit 1
fi

echo "✔ Subdomain RRset exists."
echo ""


################################################################################
# CREATE RESTRICTED TOKEN
################################################################################

echo "Creating restricted token '$TOKEN_NAME'..."

TOKEN_CREATE_PAYLOAD=$(jq -c -n --arg name "$TOKEN_NAME" '$ARGS.named')

TOKEN_CREATE_RESPONSE=$(curl -s -X POST https://desec.io/api/v1/auth/tokens/ \
  -H "Authorization: Token $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TOKEN_CREATE_PAYLOAD")

RESTRICTED_TOKEN=$(echo "$TOKEN_CREATE_RESPONSE" | jq -r '.token')
TOKEN_ID=$(echo "$TOKEN_CREATE_RESPONSE" | jq -r '.id')

if [[ -z "$TOKEN_ID" || "$TOKEN_ID" == "null" ]]; then
  echo "❌ Failed to create restricted token:"
  echo "$TOKEN_CREATE_RESPONSE"
  exit 1
fi

echo "✔ Restricted token created. ID: $TOKEN_ID"
echo ""


################################################################################
# DEFAULT POLICY
################################################################################

echo "Creating default policy…"

DEFAULT_POLICY_PAYLOAD=$(jq -c -n '{domain:null, subname:null, type:null}')

DEFAULT_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://desec.io/api/v1/auth/tokens/$TOKEN_ID/policies/rrsets/" \
  -H "Authorization: Token $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$DEFAULT_POLICY_PAYLOAD")

DEFAULT_BODY=$(echo "$DEFAULT_RESPONSE" | sed '$d')
DEFAULT_CODE=$(echo "$DEFAULT_RESPONSE" | tail -n1)

if [[ "$DEFAULT_CODE" != "201" ]]; then
  echo "❌ Failed to create DEFAULT policy"
  echo "HTTP $DEFAULT_CODE"
  echo "$DEFAULT_BODY"
  exit 1
fi

echo "✔ Default policy created."
echo ""


################################################################################
# A RECORD POLICY
################################################################################

echo "Creating A-record policy…"

A_POLICY_PAYLOAD=$(jq -c -n \
  --arg domain "$DOMAIN" \
  --arg subname "$SUBNAME" \
  '{domain:$domain, subname:$subname, type:"A", perm_write:true}')

A_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://desec.io/api/v1/auth/tokens/$TOKEN_ID/policies/rrsets/" \
  -H "Authorization: Token $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$A_POLICY_PAYLOAD")

A_BODY=$(echo "$A_RESPONSE" | sed '$d')
A_CODE=$(echo "$A_RESPONSE" | tail -n1)

if [[ "$A_CODE" != "201" ]]; then
  echo "❌ Failed to create A policy"
  echo "HTTP $A_CODE"
  echo "$A_BODY"
  exit 1
fi

echo "✔ A record policy created."
echo ""


################################################################################
# AAAA RECORD POLICY
################################################################################

echo "Creating AAAA-record policy…"

AAAA_POLICY_PAYLOAD=$(jq -c -n \
  --arg domain "$DOMAIN" \
  --arg subname "$SUBNAME" \
  '{domain:$domain, subname:$subname, type:"AAAA", perm_write:true}')

AAAA_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "https://desec.io/api/v1/auth/tokens/$TOKEN_ID/policies/rrsets/" \
  -H "Authorization: Token $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$AAAA_POLICY_PAYLOAD")

AAAA_BODY=$(echo "$AAAA_RESPONSE" | sed '$d')
AAAA_CODE=$(echo "$AAAA_RESPONSE" | tail -n1)

if [[ "$AAAA_CODE" != "201" ]]; then
  echo "❌ Failed to create AAAA policy"
  echo "HTTP $AAAA_CODE"
  echo "$AAAA_BODY"
  exit 1
fi

echo "✔ AAAA record policy created."
echo ""


################################################################################
# FINISH
################################################################################

echo "=============================================="
echo " Restricted Token Successfully Created!"
echo ""
echo " Token name:   $TOKEN_NAME"
echo " Token ID:     $TOKEN_ID"
echo " Full domain:  $FULLDOMAIN"
echo " Domain:       $DOMAIN"
echo " Subname:      $SUBNAME"
echo ""
echo " Use this token for DDNS updates:"
echo ""
echo "$RESTRICTED_TOKEN"
echo "=============================================="
echo ""
