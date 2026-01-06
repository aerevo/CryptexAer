# 🔒 CryptexLock Mirror Server

Zero-Knowledge Proof validation server for CryptexLock security system.

## 🚀 Quick Start

### Prerequisites
- Node.js >= 16.0.0
- npm >= 8.0.0
- (Optional) Redis for distributed rate limiting

### Installation

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env
nano .env  # Edit configuration

# 3. Generate secrets
node -e "console.log('HMAC_SECRET=' + require('crypto').randomBytes(32).toString('hex'))"
node -e "console.log('JWT_SECRET=' + require('crypto').randomBytes(32).toString('hex'))"

# Add generated secrets to .env file

# 4. Start server
npm start

# Or development mode with auto-reload
npm run dev
```

## 📦 Deployment

### Option 1: Traditional Server (VPS/Dedicated)

```bash
# Install PM2 for process management
npm install -g pm2

# Start with PM2
pm2 start server.js --name cryptex-mirror

# Enable auto-restart on boot
pm2 startup
pm2 save
```

### Option 2: Docker

```bash
# Build image
docker build -t cryptexlock-server .

# Run container
docker run -d \
  --name cryptex-mirror \
  -p 3000:3000 \
  --env-file .env \
  cryptexlock-server
```

### Option 3: Cloud Platforms

**AWS (Elastic Beanstalk):**
```bash
eb init
eb create cryptex-mirror-prod
eb deploy
```

**Google Cloud (App Engine):**
```bash
gcloud app deploy
```

**Heroku:**
```bash
heroku create cryptex-mirror
git push heroku main
```

## 🔧 Configuration

### Essential Environment Variables

```bash
# Security (REQUIRED)
HMAC_SECRET=<your_secret_here>
JWT_SECRET=<your_secret_here>

# Server
PORT=3000
NODE_ENV=production

# Rate Limiting
RATE_LIMIT_MAX_REQUESTS=5
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes

# Biometric Thresholds
MIN_CONFIDENCE_SCORE=0.85
MIN_ENTROPY=0.5
MIN_TREMOR_HZ=7.5
MAX_TREMOR_HZ=13.5
```

### Optional: Redis (for scaling)

```bash
# Install Redis
sudo apt-get install redis-server

# Enable in .env
REDIS_ENABLED=true
REDIS_URL=redis://localhost:6379
```

## 🔐 Security Best Practices

### 1. Use HTTPS Only

```nginx
# Nginx reverse proxy
server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. Configure Firewall

```bash
# UFW example
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 3. Enable Monitoring

```bash
# Install monitoring tools
npm install pm2-logrotate
pm2 install pm2-logrotate
```

## 📊 Monitoring

### Health Check

```bash
curl https://api.yourdomain.com/health
```

### Logs

```bash
# PM2 logs
pm2 logs cryptex-mirror

# Or direct logs
tail -f logs/app.log
```

## 🧪 Testing

```bash
# Run tests
npm test

# Load testing
npm install -g artillery
artillery quick --count 10 --num 50 https://api.yourdomain.com/api/v1/verify
```

## 🔄 Updates

```bash
# Pull latest changes
git pull origin main

# Install dependencies
npm install

# Restart with zero downtime
pm2 reload cryptex-mirror
```

## 📈 Scaling

### Horizontal Scaling

1. Enable Redis for shared rate limiting
2. Deploy multiple instances
3. Use load balancer (Nginx, HAProxy, AWS ALB)

```nginx
# Nginx load balancer
upstream cryptex_backend {
    server 127.0.0.1:3000;
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
}

server {
    location / {
        proxy_pass http://cryptex_backend;
    }
}
```

## 🐛 Troubleshooting

### Issue: Rate limit too strict
```bash
# Increase limits in .env
RATE_LIMIT_MAX_REQUESTS=10
```

### Issue: Server timeout
```bash
# Increase timeout in client
serverTimeout = const Duration(seconds: 10);
```

### Issue: Memory usage high
```bash
# Monitor memory
pm2 monit

# Restart if needed
pm2 restart cryptex-mirror
```

## 📞 Support

For issues or questions:
- GitHub Issues: https://github.com/yourrepo/issues
- Email: support@yourdomain.com

## 📄 License

MIT License - See LICENSE file for details
