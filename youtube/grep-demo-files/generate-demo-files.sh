#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR="${1:-grep-demo}"

mkdir -p "$DEMO_DIR/logs" "$DEMO_DIR/configs" "$DEMO_DIR/app"

cat > "$DEMO_DIR/logs/app.log" <<'EOF'
2026-05-31 08:00:01 INFO Application starting version=1.8.4 env=production
2026-05-31 08:00:02 INFO Loading configuration from configs/app.env
2026-05-31 08:00:03 INFO DB_HOST=db01.internal
2026-05-31 08:01:10 INFO user login successful user_id=1001 ip=10.0.1.15
2026-05-31 08:02:44 WARNING cache latency is high duration_ms=850
2026-05-31 08:03:12 ERROR database connection failed: timeout while connecting to db01.internal:5432
2026-05-31 08:03:13 WARNING retrying database connection attempt=1
2026-05-31 08:03:15 ERROR database connection failed: connection refused
2026-05-31 08:04:20 INFO user login successful user_id=1002 ip=10.0.1.19
2026-05-31 08:05:09 ERROR payment failed order_id=88421 reason=processor timeout
2026-05-31 08:05:10 WARNING payment service response was slow duration_ms=3200
2026-05-31 08:05:11 ERROR 500 internal server error request_id=req-9f81 path=/checkout
2026-05-31 08:06:01 INFO healthcheck passed status=ok
2026-05-31 08:07:34 WARNING disk usage above threshold usage=82%
2026-05-31 08:08:45 ERROR timeout waiting for upstream service service=inventory
2026-05-31 08:09:22 INFO user logout successful user_id=1001
ERROR legacy worker failed to publish retry event
2026-05-31 08:10:30 INFO Application shutdown requested
EOF

cat > "$DEMO_DIR/logs/nginx-access.log" <<'EOF'
10.0.1.15 - - [31/May/2026:08:01:10 +0300] "GET / HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
10.0.1.19 - - [31/May/2026:08:02:18 +0300] "GET /api/users HTTP/1.1" 200 2048 "-" "curl/8.0"
192.168.1.50 - - [31/May/2026:08:02:45 +0300] "GET /admin HTTP/1.1" 404 512 "-" "Mozilla/5.0"
203.0.113.10 - - [31/May/2026:08:03:01 +0300] "GET /wp-login.php HTTP/1.1" 404 256 "-" "sqlmap"
10.0.1.15 - - [31/May/2026:08:03:20 +0300] "POST /login HTTP/1.1" 301 128 "-" "Mozilla/5.0"
198.51.100.23 - - [31/May/2026:08:04:01 +0300] "GET /api/users?id=1' HTTP/1.1" 404 321 "-" "suspicious-scanner"
10.0.1.19 - - [31/May/2026:08:05:11 +0300] "POST /checkout HTTP/1.1" 500 612 "-" "Mozilla/5.0"
10.0.1.22 - - [31/May/2026:08:05:13 +0300] "GET /api/users HTTP/1.1" 500 600 "-" "curl/8.0"
10.0.1.23 - - [31/May/2026:08:06:01 +0300] "GET /healthcheck HTTP/1.1" 200 64 "-" "kube-probe/1.30"
203.0.113.77 - - [31/May/2026:08:07:55 +0300] "GET /.env HTTP/1.1" 404 300 "-" "badbot"
EOF

cat > "$DEMO_DIR/logs/auth.log" <<'EOF'
May 31 08:00:01 server01 sshd[1011]: Server listening on 0.0.0.0 port 22.
May 31 08:01:22 server01 sshd[1042]: Accepted password for deploy from 10.0.1.10 port 54322 ssh2
May 31 08:02:10 server01 sshd[1075]: Failed password for invalid user admin from 203.0.113.10 port 52218 ssh2
May 31 08:02:15 server01 sshd[1075]: Failed password for invalid user admin from 203.0.113.10 port 52218 ssh2
May 31 08:03:44 server01 sshd[1081]: Failed password for root from 198.51.100.23 port 51110 ssh2
May 31 08:04:05 server01 sshd[1099]: Invalid user test from 203.0.113.77 port 49999
May 31 08:04:09 server01 sshd[1099]: Failed password for invalid user test from 203.0.113.77 port 49999 ssh2
May 31 08:05:30 server01 sudo: deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/bin/systemctl restart nginx
May 31 08:07:01 server01 sshd[1110]: Accepted password for ubuntu from 10.0.1.15 port 54400 ssh2
May 31 08:08:42 server01 sshd[1130]: Failed password for root from 192.168.1.50 port 45512 ssh2
EOF

cat > "$DEMO_DIR/configs/nginx.conf" <<'EOF'
server {
    listen 80;
    server_name app.example.com;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

cat > "$DEMO_DIR/configs/app.env" <<'EOF'
DB_HOST=db01.internal
DB_PORT=5432
DB_PASSWORD=demo_password_not_real
API_KEY=demo_api_key_not_real
DEBUG=true
PORT=8080
EOF

cat > "$DEMO_DIR/app/main.py" <<'EOF'
import logging
import os

logging.basicConfig(level=logging.INFO)

DB_HOST = os.getenv("DB_HOST", "localhost")


def connect_to_database():
    # TODO: add retry backoff
    try:
        logging.info("connecting to database host=%s", DB_HOST)
        raise TimeoutError("database connection failed")
    except TimeoutError as error:
        logging.error("database connection failed: %s", error)
        return False


def handle_payment(order_id):
    try:
        logging.info("processing payment order_id=%s", order_id)
        raise RuntimeError("payment failed")
    except RuntimeError as error:
        logging.error("payment failed order_id=%s error=%s", order_id, error)
        return False


if __name__ == "__main__":
    connect_to_database()
    handle_payment("88421")
EOF

echo "Demo files created in: $DEMO_DIR"

if command -v tree >/dev/null 2>&1; then
    tree "$DEMO_DIR"
else
    find "$DEMO_DIR"
fi

