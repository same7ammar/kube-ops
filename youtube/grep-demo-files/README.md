# grep Linux Guide: Search and Troubleshoot Faster

## 1. Video Objective

By the end of this video, the viewer will know how to use `grep` to:

* Search text inside files.
* Search logs quickly.
* Filter errors and warnings.
* Search recursively inside folders.
* Combine `grep` with other Linux commands.
* Use `grep` for real troubleshooting.
* Understand basic regex with `grep`.
* Avoid common `grep` mistakes.

> Instructor note: Keep this video practical. Show commands, show output, explain the situation, then move to the next troubleshooting step.

## 2. What is grep?

`grep` searches for patterns inside text.

You can use it to search:

* One file.
* Multiple files.
* Command output.
* Log files.
* Config files.
* Entire directories.

It is one of the most important Linux troubleshooting tools because most Linux problems leave clues in text: logs, configs, process output, systemd output, Docker logs, Kubernetes events, and application errors.

Basic syntax:

```bash
grep "pattern" file
```

Meaning:

* `pattern` is what you are searching for.
* `file` is where you are searching.

Example:

```bash
grep "ERROR" logs/app.log
```

This searches for the word `ERROR` inside `logs/app.log`.

## 3. Prepare Demo Environment

Run these commands from the directory where you want to create the demo.

```bash
mkdir -p grep-demo/logs grep-demo/configs grep-demo/app
```

Create an application log:

```bash
cat > grep-demo/logs/app.log <<'EOF'
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
```

Create an Nginx access log:

```bash
cat > grep-demo/logs/nginx-access.log <<'EOF'
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
```

Create an auth log:

```bash
cat > grep-demo/logs/auth.log <<'EOF'
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
```

Create an Nginx config:

```bash
cat > grep-demo/configs/nginx.conf <<'EOF'
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
```

Create an app environment file:

```bash
cat > grep-demo/configs/app.env <<'EOF'
DB_HOST=db01.internal
DB_PORT=5432
DB_PASSWORD=demo_password_not_real
API_KEY=demo_api_key_not_real
DEBUG=true
PORT=8080
EOF
```

Create a small Python application file:

```bash
cat > grep-demo/app/main.py <<'EOF'
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
```

Show the demo structure:

```bash
tree grep-demo
```

If `tree` is not installed:

```bash
find grep-demo
```

Move into the demo folder for the rest of the video:

```bash
cd grep-demo
```

> Instructor note: The fake `DB_PASSWORD` and `API_KEY` are for demo only. In real videos, remind viewers not to print real secrets on screen.

## 4. Basic grep Commands

### Search for a word in a file

```bash
grep "ERROR" logs/app.log
```

Searches for lines containing `ERROR`.

### Case-insensitive search

```bash
grep -i "error" logs/app.log
```

Finds `error`, `ERROR`, `Error`, or any other case variation.

### Show line numbers

```bash
grep -n "ERROR" logs/app.log
```

Shows the line number before each matching line. This is useful when you need to open the file and jump to the problem.

### Search multiple words separately

```bash
grep "ERROR" logs/app.log
grep "WARNING" logs/app.log
grep "timeout" logs/app.log
```

Use this when you want to check one issue at a time.

### Search in multiple files

```bash
grep "ERROR" logs/app.log logs/nginx-access.log
```

Searches both files and prints the file name before each match.

### Search all files in a directory

```bash
grep "ERROR" logs/*
```

Searches every regular file directly inside `logs/`.

> Instructor note: Start simple. Most real troubleshooting starts with one keyword like `ERROR`, `failed`, `timeout`, or `denied`.

## 5. Recursive Search

Use recursive search when you do not know which file contains the text.

```bash
grep -r "DB_HOST" .
grep -r "server_name" .
grep -r "TODO" .
```

Explanation:

* `-r` searches recursively inside directories.
* `.` means start from the current directory.
* This is useful for projects, configs, scripts, and logs.

`-R` is similar, but it also follows symbolic links. In most beginner demos, `-r` is the safer default.

Production example:

```bash
grep -r "proxy_pass" /etc/nginx/
```

This helps you find where an Nginx reverse proxy is configured.

## 6. Show File Names Only

Sometimes you do not need the matching line. You only need to know which file contains the match.

```bash
grep -rl "ERROR" .
grep -rl "DB_PASSWORD" .
grep -rl "proxy_pass" configs/
```

Explanation:

* `-r` searches recursively.
* `-l` prints only file names with matches.

This is useful when you want to find the right config file quickly.

## 7. Count Matches

```bash
grep -c "ERROR" logs/app.log
grep -c "404" logs/nginx-access.log
grep -c "Failed password" logs/auth.log
```

`-c` counts matching lines.

This helps you answer questions like:

* How many errors happened?
* Are 404s repeating?
* How many failed SSH login attempts do we have?

> Instructor note: Counting is helpful during incidents because it turns noise into a number.

## 8. Invert Match

`-v` means exclude matching lines.

```bash
grep -v "INFO" logs/app.log
grep -v "200" logs/nginx-access.log
```

Real example:

```bash
grep -v "healthcheck" logs/nginx-access.log
```

This removes noisy healthcheck lines from the output.

You can combine options:

```bash
grep -vi "healthcheck" logs/nginx-access.log
```

This excludes `healthcheck` in any letter case.

## 9. Match Whole Word

Use `-w` when you want a whole word match.

```bash
grep -w "ERROR" logs/app.log
grep -w "root" logs/auth.log
```

Why this matters:

```bash
grep "root" logs/auth.log
```

This may match `root`, but in other files it could also match longer words that contain `root`.

`-w` is stricter.

## 10. Match Exact Line

```bash
grep -x "DEBUG=true" configs/app.env
```

`-x` matches the whole line exactly.

This is useful for config validation when you want to confirm a line exists exactly as expected.

Another example:

```bash
grep -x "PORT=8080" configs/app.env
```

## 11. Show Context Around Matches

Context is one of the most useful `grep` features for troubleshooting.

* `-A` shows lines after the match.
* `-B` shows lines before the match.
* `-C` shows lines before and after the match.

Show lines after:

```bash
grep -A 3 "ERROR" logs/app.log
```

Show lines before:

```bash
grep -B 3 "ERROR" logs/app.log
```

Show lines before and after:

```bash
grep -C 3 "ERROR" logs/app.log
```

Real troubleshooting example:

```bash
grep -C 5 "database connection failed" logs/app.log
```

This helps you see what happened before and after the database failure.

> Instructor note: In real incidents, `grep -C` is often more useful than plain `grep` because one line is rarely the full story.

## 12. grep with Command Output

`grep` becomes even more powerful when you combine it with pipes.

The pipe symbol `|` sends the output of one command into another command.

Search running processes:

```bash
ps aux | grep nginx
ps aux | grep ssh
```

Search systemd status output:

```bash
systemctl status ssh | grep Active
```

On some distributions, the service may be named `sshd`:

```bash
systemctl status sshd | grep Active
```

Search IP address output:

```bash
ip addr | grep inet
```

Search disk usage output:

```bash
df -h | grep "/"
```

Avoid matching the `grep` command itself:

```bash
ps aux | grep nginx | grep -v grep
```

Better alternative for process search:

```bash
pgrep -a nginx
```

> Instructor note: Show `ps aux | grep nginx` first because people see it everywhere. Then show `pgrep -a nginx` as the cleaner tool.

## 13. grep with systemd Logs

Use `journalctl` to inspect systemd logs, then pipe to `grep`.

```bash
journalctl -u nginx | grep -i error
journalctl -u ssh | grep -i failed
journalctl -xe | grep -i "permission denied"
```

With time filters:

```bash
journalctl --since "10 minutes ago" | grep -i error
journalctl --since today | grep -i failed
```

Common real commands:

```bash
journalctl -u nginx --since "1 hour ago" | grep -Ei "error|failed|timeout|denied"
journalctl -u docker --since today | grep -i error
journalctl -u kubelet --since "30 minutes ago" | grep -Ei "failed|error|warning"
```

> Instructor note: Explain that `journalctl` narrows the time or service, and `grep` narrows the message.

## 14. grep with Nginx Logs

Search status codes and paths:

```bash
grep "404" logs/nginx-access.log
grep "500" logs/nginx-access.log
grep "/api/users" logs/nginx-access.log
grep "POST /login" logs/nginx-access.log
```

Find bad status codes:

```bash
grep -E " 4[0-9]{2} | 5[0-9]{2} " logs/nginx-access.log
```

Find requests from a specific IP:

```bash
grep "192.168.1.50" logs/nginx-access.log
```

Find suspicious paths:

```bash
grep -E "/wp-login\.php|/\.env|/admin" logs/nginx-access.log
```

Count server errors:

```bash
grep -c " 500 " logs/nginx-access.log
```

> Instructor note: Access logs help answer who, what path, what status code, and when.

## 15. grep with SSH/Auth Logs

Search common SSH events:

```bash
grep "Failed password" logs/auth.log
grep "Accepted password" logs/auth.log
grep "invalid user" logs/auth.log
grep "root" logs/auth.log
```

Count failed login attempts:

```bash
grep -c "Failed password" logs/auth.log
```

Extract suspicious IPs using `grep` and `awk`:

```bash
grep "Failed password" logs/auth.log | awk '{print $(NF-3)}'
```

Show unique IPs:

```bash
grep "Failed password" logs/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr
```

This is a real security troubleshooting pattern:

1. Search for failed logins.
2. Extract the source IP.
3. Count repeated attempts.
4. Investigate or block the worst offenders.

> Instructor note: Mention that auth log paths vary. Ubuntu often uses `/var/log/auth.log`; RHEL-based systems often use `/var/log/secure`.

## 16. grep with Docker

Search containers:

```bash
docker ps | grep nginx
docker ps -a | grep Exited
```

Search container logs:

```bash
docker logs <container-name> 2>&1 | grep -i error
docker logs <container-name> 2>&1 | grep -i "connection refused"
docker logs <container-name> 2>&1 | grep -C 3 -i "exception"
```

Why `2>&1`?

Some logs are written to standard error instead of standard output. `2>&1` combines both streams so `grep` can search everything.

More practical examples:

```bash
docker logs app 2>&1 | grep -Ei "error|failed|timeout|exception|refused"
docker logs --since 10m app 2>&1 | grep -i error
docker compose logs app 2>&1 | grep -Ei "error|failed|timeout"
```

## 17. grep with Kubernetes

Search pod status:

```bash
kubectl get pods -A | grep CrashLoopBackOff
kubectl get pods -A | grep Pending
```

Search events:

```bash
kubectl get events -A | grep -i failed
kubectl get events -A | grep -i warning
```

Search pod logs:

```bash
kubectl logs <pod-name> | grep -i error
kubectl logs <pod-name> -n <namespace> | grep -i exception
```

Search pod describe output:

```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 -i events
```

Real troubleshooting examples:

```bash
kubectl get pods -A | grep -E "CrashLoopBackOff|Error|ImagePullBackOff|Pending"
```

```bash
kubectl get events -A | grep -E "Failed|BackOff|Unhealthy|Killing"
```

More focused examples:

```bash
kubectl logs deployment/app -n production | grep -Ei "error|failed|timeout|exception"
kubectl describe pod app-123 -n production | grep -Ei "reason|message|failed|warning"
```

> Instructor note: Kubernetes output is large. `grep` helps you get to the signal quickly, especially in events and describe output.

## 18. Basic Regex with grep

Regex means pattern matching. Keep it simple for beginners.

### Search for error or warning

```bash
grep -E "ERROR|WARNING" logs/app.log
```

`|` means OR when using `grep -E`.

### Search for 4xx and 5xx status codes

```bash
grep -E " 4[0-9]{2} | 5[0-9]{2} " logs/nginx-access.log
```

Meaning:

* `4[0-9]{2}` matches `400` through `499`.
* `5[0-9]{2}` matches `500` through `599`.

### Search for lines starting with ERROR

```bash
grep "^ERROR" logs/app.log
```

`^` means start of line.

### Search for lines ending with true

```bash
grep "true$" configs/app.env
```

`$` means end of line.

### Search for empty lines

```bash
grep "^$" file.txt
```

### Search for non-empty lines

```bash
grep -v "^$" file.txt
```

> Instructor note: Do not turn this into a full regex lesson. Teach only what helps people troubleshoot.

## 19. Extended grep

Use:

```bash
grep -E
```

`-E` means extended regex. It makes patterns like OR easier to write.

Examples:

```bash
grep -E "ERROR|timeout|failed" logs/app.log
grep -Ei "error|timeout|failed|exception" logs/app.log
```

Breakdown:

* `-E` enables extended regex.
* `-i` ignores case.
* `error|timeout|failed|exception` searches for multiple problem words.

This is one of the most useful troubleshooting commands:

```bash
grep -Ein "error|failed|timeout|exception|refused|denied" logs/app.log
```

This gives:

* Extended regex.
* Case-insensitive search.
* Line numbers.
* Multiple error patterns.

## 20. Highlight Matches

Highlight matching text:

```bash
grep --color=always "ERROR" logs/app.log
```

Better default alias:

```bash
alias grep='grep --color=auto'
```

Make it permanent for Bash:

```bash
echo "alias grep='grep --color=auto'" >> ~/.bashrc
source ~/.bashrc
```

For Zsh:

```bash
echo "alias grep='grep --color=auto'" >> ~/.zshrc
source ~/.zshrc
```

> Instructor note: For video recording, color helps viewers immediately see what matched.

## 21. Search Hidden or Specific File Types

Search only `.log` files:

```bash
grep -r --include="*.log" "ERROR" .
```

Search only config files:

```bash
grep -r --include="*.conf" "server_name" .
```

Exclude files:

```bash
grep -r --exclude="*.env" "PASSWORD" .
```

Exclude directories:

```bash
grep -r --exclude-dir=".git" "TODO" .
```

Search hidden files too:

```bash
grep -r "API_KEY" .
```

If you want to avoid binary files:

```bash
grep -rI "ERROR" .
```

## 22. Useful grep Options Cheat Sheet

| Option | Meaning | Example |
| --- | --- | --- |
| `-i` | Ignore case | `grep -i error app.log` |
| `-n` | Show line number | `grep -n ERROR app.log` |
| `-r` | Recursive search | `grep -r TODO .` |
| `-v` | Invert match | `grep -v INFO app.log` |
| `-c` | Count matches | `grep -c ERROR app.log` |
| `-l` | Show file names only | `grep -rl ERROR .` |
| `-w` | Whole word | `grep -w root auth.log` |
| `-x` | Whole line | `grep -x DEBUG=true app.env` |
| `-A` | Lines after match | `grep -A 3 ERROR app.log` |
| `-B` | Lines before match | `grep -B 3 ERROR app.log` |
| `-C` | Context before and after | `grep -C 3 ERROR app.log` |
| `-E` | Extended regex | `grep -E "ERROR|WARN" app.log` |
| `--include` | Search matching file types | `grep -r --include="*.log" ERROR .` |
| `--exclude-dir` | Skip directories | `grep -r --exclude-dir=".git" TODO .` |

## 23. Real Troubleshooting Workflow

Scenario:

> The application is down and users are getting 500 errors.

### Step 1: Check Nginx 500 errors

```bash
grep "500" logs/nginx-access.log
```

You confirm that users are receiving HTTP 500 responses.

### Step 2: Search application errors

```bash
grep -i "error" logs/app.log
```

You search the application log for error messages.

### Step 3: Search with context

```bash
grep -C 5 -i "database connection failed" logs/app.log
```

You check what happened before and after the database failure.

### Step 4: Check config

```bash
grep "DB_HOST" configs/app.env
```

You verify which database host the app is trying to use.

### Step 5: Search for timeout

```bash
grep -i "timeout" logs/app.log
```

You look for timeout-related messages.

### Step 6: Find all related issues

```bash
grep -Ei "error|failed|timeout|exception|refused" logs/app.log
```

This searches for multiple failure patterns in one command.

Incident response explanation:

1. Start with the user-facing symptom: HTTP 500.
2. Move from Nginx logs to app logs.
3. Use context to understand the timeline.
4. Check config values related to the failure.
5. Search for related symptoms like timeouts or refused connections.
6. Build a quick theory: the app is failing because it cannot connect to the database or upstream service.

> Instructor note: This section should feel like a real incident. Say what you are checking and why before each command.

## 24. Advanced Troubleshooting Examples

### Find most common errors

```bash
grep -i "error" logs/app.log | sort | uniq -c | sort -nr
```

This groups repeated error lines and sorts the most common ones first.

### Search compressed logs

```bash
zgrep "ERROR" app.log.gz
```

Useful when old logs are compressed.

### Follow logs and grep live

```bash
tail -f logs/app.log | grep -i error
```

Shows new error lines as they happen.

### Follow multiple patterns live

```bash
tail -f logs/app.log | grep -Ei "error|failed|timeout|exception"
```

Good during live debugging.

### Save grep result to file

```bash
grep -Ei "error|failed|timeout" logs/app.log > errors-found.txt
```

Creates or overwrites `errors-found.txt`.

### Append result to file

```bash
grep "500" logs/nginx-access.log >> incident-report.txt
```

Adds output to the end of `incident-report.txt`.

### Include line numbers in an incident note

```bash
grep -Ein "error|failed|timeout|exception|refused" logs/app.log > incident-errors.txt
```

This makes it easier to share findings with teammates.

## 25. Common Mistakes

### Mistake 1: Forgetting quotes

Wrong:

```bash
grep connection failed logs/app.log
```

This does not search for the full phrase `connection failed`. The shell treats `connection` and `failed` as separate arguments.

Correct:

```bash
grep "connection failed" logs/app.log
```

### Mistake 2: Forgetting case sensitivity

This may miss uppercase `ERROR`:

```bash
grep "error" logs/app.log
```

Better:

```bash
grep -i "error" logs/app.log
```

### Mistake 3: Searching binary files accidentally

Use:

```bash
grep -rI "ERROR" .
```

`-I` tells `grep` to ignore binary files.

### Mistake 4: Too much output

Plain search can print too much:

```bash
grep "ERROR" logs/app.log
```

Better:

```bash
grep -n "ERROR" logs/app.log
grep -C 3 "ERROR" logs/app.log
```

### Mistake 5: Searching the wrong folder

Check where you are:

```bash
pwd
ls
```

Then search:

```bash
grep -r "ERROR" .
```

## 26. grep vs find vs awk vs sed

Use the right tool:

* `grep` searches text.
* `find` searches files by name, size, date, or path.
* `awk` processes columns and fields.
* `sed` edits or transforms text.

Find log files:

```bash
find . -name "*.log"
```

Find log files and search inside them:

```bash
find . -name "*.log" -exec grep "ERROR" {} \;
```

Search errors, then print selected columns:

```bash
grep "ERROR" logs/app.log | awk '{print $1, $2, $3}'
```

Use `grep` first when the question is:

* Which lines contain this text?
* Which files contain this pattern?
* How many times does this error appear?

Use `awk` after `grep` when you need fields or columns.

## 27. Final Fast grep Aliases

Useful aliases:

```bash
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias grep-errors='grep -Ei "error|failed|timeout|exception|refused|denied"'
```

Usage:

```bash
grep-errors logs/app.log
```

Another useful alias with line numbers:

```bash
alias grep-errors-n='grep -Ein "error|failed|timeout|exception|refused|denied"'
```

Usage:

```bash
grep-errors-n logs/app.log
```

> Instructor note: Aliases are convenient, but during teaching, show the full command first so beginners understand what is happening.

## 28. Final Summary

Remember the practical `grep` workflow:

* Start simple.
* Add `-i` for case-insensitive search.
* Add `-n` for line numbers.
* Add `-C` when you need context.
* Use `-r` when searching projects, logs, or configs.
* Use `grep -E` for multiple patterns.
* Combine `grep` with `journalctl`, `docker logs`, `kubectl logs`, `tail -f`, `awk`, `sort`, and `uniq`.

`grep` is not just a command. It is a troubleshooting habit.

## 29. Video Closing Script

If you work with Linux, servers, Docker, Kubernetes, or logs, `grep` is one of the tools you will use every single day.

Mastering `grep` will save you minutes during normal work, and sometimes hours during incidents.

If this video was useful, like the video, subscribe for more practical Linux, Docker, Kubernetes, and DevOps content, and comment with the command you use most when troubleshooting.
