const express = require('express');
const os = require('os');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Helper function to render HTML templates
function renderTemplate(templateName, data) {
  const templatePath = path.join(__dirname, 'views', templateName);
  let html = fs.readFileSync(templatePath, 'utf8');

  // Replace all placeholders with actual data
  for (const [key, value] of Object.entries(data)) {
    html = html.replace(new RegExp(`{{${key}}}`, 'g'), value);
  }

  return html;
}

// GET endpoint with fancy HTML response
app.get('/', (req, res) => {
  const hostname = os.hostname();
  const emoji = ['🐳', '⚡', '🔥', '💪', '🎯'][Math.floor(Math.random() * 5)];

  const html = renderTemplate('index.html', {
    EMOJI: emoji,
    HOSTNAME: hostname,
    CONTAINER_ID: hostname.substring(0, 12),
    PLATFORM: os.platform(),
    ARCH: os.arch(),
    NODE_VERSION: process.version,
    UPTIME: (process.uptime() / 60).toFixed(2),
    METHOD: req.method,
    PATH: req.path,
    TIMESTAMP: new Date().toLocaleTimeString()
  });

  res.send(html);
});

// Health check endpoint
app.get('/health', (req, res) => {
  const html = renderTemplate('health.html', {
    HOSTNAME: os.hostname(),
    UPTIME: (process.uptime() / 60).toFixed(2),
    TIMESTAMP: new Date().toLocaleString()
  });

  res.send(html);
});

// Info endpoint with detailed system info
app.get('/info', (req, res) => {
  const totalMem = (os.totalmem() / 1024 / 1024 / 1024).toFixed(2);
  const freeMem = (os.freemem() / 1024 / 1024 / 1024).toFixed(2);
  const usedMem = (totalMem - freeMem).toFixed(2);
  const memPercent = ((usedMem / totalMem) * 100).toFixed(1);

  const html = renderTemplate('info.html', {
    HOSTNAME: os.hostname(),
    PLATFORM: os.platform(),
    ARCH: os.arch(),
    PID: process.pid,
    CPU_CORES: os.cpus().length,
    CPU_MODEL: os.cpus()[0].model.substring(0, 25) + '...',
    CPU_SPEED: os.cpus()[0].speed,
    TOTAL_MEM: totalMem,
    USED_MEM: usedMem,
    FREE_MEM: freeMem,
    MEM_PERCENT: memPercent,
    SYSTEM_UPTIME: (os.uptime() / 60 / 60).toFixed(2),
    PROCESS_UPTIME: (process.uptime() / 60).toFixed(2),
    NODE_VERSION: process.version
  });

  res.send(html);
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📦 Hostname: ${os.hostname()}`);
  console.log(`🐳 Container ID: ${os.hostname().substring(0, 12)}`);
});
