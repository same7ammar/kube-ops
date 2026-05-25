# VPS Server Hardening — Step by Step

## Step 1 — Create a Non-Root User

Running everything as root is dangerous — a single mistake can destroy the system. This creates a limited user (`deploy`) that can only use `sudo` when needed, reducing the blast radius of any error.

```bash
adduser deploy
usermod -aG sudo deploy
```

---

## Step 2 — Set Up SSH Key Authentication

Passwords can be brute-forced. SSH keys are cryptographically strong and nearly impossible to crack remotely. You'll generate a key pair on your local machine and copy the public key to the server — after this, only your machine can log in.

**On your local machine:**

```bash
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p 22 deploy@YOUR_SERVER_IP
```

---

## Step 3 — Harden SSH Configuration

SSH's default settings are wide open. This step locks it down: moves SSH off port 22 (eliminates the majority of automated scan traffic), disables root login, turns off password authentication entirely, and restricts which user can log in.

```bash
sudo nano /etc/ssh/sshd_config
```

Set these values (add or update each line):

```
Port 2222
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowUsers deploy
ClientAliveInterval 300
ClientAliveCountMax 2
```

---

## Step 4 — Fix Cloud-Init SSH Override

Cloud providers (DigitalOcean, AWS, Hetzner, etc.) use a tool called cloud-init that rewrites SSH config on every reboot — silently undoing your Step 3 changes. This step overrides that file and tells cloud-init to stop touching SSH settings.

```bash
echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/50-cloud-init.conf
```

Prevent cloud-init from resetting it on reboot:

```bash
sudo nano /etc/cloud/cloud.cfg.d/99-disable-ssh-pw.cfg
```

```yaml
ssh_pwauth: false
```

Reload SSH to apply all changes from Steps 3 and 4. Use `reload` (not `restart`) — it re-reads the config without dropping your current session. No `daemon-reload` is needed; that's only for changes to `.service` unit files, not config files.

```bash
sudo systemctl reload ssh
```

---

## Step 5 — Lock the Root Account

Even with root login disabled in SSH, the root account itself still exists and could be accessed from the server console. Locking it adds a second layer — no one can authenticate as root through any method.

```bash
sudo passwd -l root
```

---

## Step 6 — Configure the Firewall (UFW)

A firewall blocks all incoming connections by default and only allows the specific ports you open. The `limit` rule on the SSH port also auto-blocks any IP that connects too frequently, adding basic brute-force protection at the network level.

```bash
sudo apt install ufw -y

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

sudo ufw enable
```

---

## Step 7 — Install and Configure Fail2ban

Fail2ban watches authentication logs and automatically bans IPs that repeatedly fail to log in. Where UFW's rate limit slows attackers down, Fail2ban cuts them off entirely after a configurable number of failures.

```bash
sudo apt install fail2ban -y
```

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime  = 24h
findtime = 10m
maxretry = 3
backend  = systemd

[sshd]
enabled  = true
port     = 2222
```

```bash
sudo systemctl enable --now fail2ban
```

---

## Step 8 — Enable Automatic Security Updates

Security patches are released constantly. Without auto-updates, your server is only as secure as the last time you manually ran `apt upgrade`. This installs patches automatically in the background so your server stays protected even when you're not watching it.

```bash
sudo apt install unattended-upgrades -y
```

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Set these options:

```conf
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
```

---

## Step 9 — Harden Kernel Parameters

These settings tune the Linux kernel's network stack for security: disabling IP forwarding (your server is not a router), enabling SYN cookies to absorb SYN flood attacks, blocking ICMP broadcast amplification, and restricting kernel pointers and debug info from leaking to unprivileged processes.

```bash
sudo nano /etc/sysctl.d/99-hardening.conf
```

```ini
net.ipv4.ip_forward = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
kernel.sysrq = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
```

```bash
sudo sysctl -p /etc/sysctl.d/99-hardening.conf
```

---

## Step 10 — Secure Critical File Permissions

SSH host keys and the shadow password file must never be world-readable. These commands enforce the correct permissions in case they were loosened by an update or misconfiguration.

```bash
sudo chmod 600 /etc/ssh/sshd_config
sudo chmod 600 /etc/shadow
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub
```

---

## Step 11 — Set Up auditd

`auditd` records file access and process events to a tamper-evident log. The rules below watch the most sensitive files on the system — if anything modifies SSH config, sudoers, or the password file, there will be a log entry you can trace back.

```bash
sudo apt install auditd -y
sudo systemctl enable --now auditd
```

```bash
sudo nano /etc/audit/rules.d/hardening.rules
```

```
-w /etc/ssh/sshd_config -p wa -k sshd-config
-w /etc/sudoers -p wa -k sudoers
-w /etc/passwd -p wa -k passwd
-w /bin/su -p x -k su-exec
```

```bash
sudo augenrules --load
```

---

## Step 12 — Set Up SSH Client Config (Local Machine)

Instead of typing the full `ssh -p 2222 -i ~/.ssh/id_ed25519 deploy@YOUR_SERVER_IP` command every time, this creates a named shortcut on your local machine so you can connect with just `ssh myserver`.

```bash
nano ~/.ssh/config
```

```
Host myserver
    HostName YOUR_SERVER_IP
    Port 2222
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

```bash
chmod 600 ~/.ssh/config
```
