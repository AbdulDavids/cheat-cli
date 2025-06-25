# Cheat CLI - Cloudflare Workers Deployment

This guide shows how to deploy the Cheat CLI API as a Cloudflare Worker instead of running a local Python server.

## Benefits of Cloudflare Workers

- ✅ **Global Edge Network**: Low latency worldwide
- ✅ **Zero Server Management**: No servers to maintain
- ✅ **High Availability**: Built-in redundancy and scaling
- ✅ **Cost Effective**: Generous free tier (100k requests/day)
- ✅ **HTTPS by Default**: Secure connections out of the box

## Prerequisites

1. **Cloudflare Account**: Sign up at [cloudflare.com](https://cloudflare.com)
2. **Node.js**: Install from [nodejs.org](https://nodejs.org)
3. **OpenAI API Key**: Get one from [platform.openai.com](https://platform.openai.com)

## Quick Setup

### 1. Install Wrangler CLI

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Set Your OpenAI API Key

```bash
wrangler secret put OPENAI_API_KEY
# Enter your OpenAI API key when prompted
```

### 4. Deploy the Worker

```bash
./deploy-worker.sh
```

Or manually:

```bash
# Deploy to staging
wrangler deploy --env staging

# Deploy to production
wrangler deploy
```

## Configuration

### Environment Variables

The worker uses these environment variables:

- `OPENAI_API_KEY` (required): Your OpenAI API key (set as a secret)

### Updating Your Shell Script

After deployment, update your `cheat.sh` to use the Worker URL:

```bash
# Replace with your actual Worker URL
export API_URL="https://cheat-cli-api.your-subdomain.workers.dev"
```

## API Endpoints

The Worker provides the same endpoints as the Python server:

- `GET /` - API info and status
- `GET /health` - Health check
- `POST /chat` - Chat completions (streaming and non-streaming)

## Development

### Local Development

```bash
# Start local development server
wrangler dev

# Test locally
export API_URL="http://localhost:8787"
./cheat.sh "Hello from local development!"
```

### Monitoring

```bash
# View real-time logs
wrangler tail

# View deployment info
wrangler whoami
```

### Updating the Worker

1. Edit `worker.js`
2. Run `wrangler deploy`

## Troubleshooting

### Common Issues

1. **"OPENAI_API_KEY not configured"**
   ```bash
   wrangler secret put OPENAI_API_KEY
   ```

2. **"Wrangler command not found"**
   ```bash
   npm install -g wrangler
   ```

3. **Authentication errors**
   ```bash
   wrangler logout
   wrangler login
   ```

### Checking Logs

```bash
# Real-time logs
wrangler tail

# Or check the Cloudflare dashboard for detailed analytics
```

## Cost Estimation

Cloudflare Workers free tier includes:
- 100,000 requests per day
- 10ms CPU time per request

For typical chat usage:
- ~1000 chat requests/day = FREE
- ~10,000 chat requests/day = FREE  
- 100,000+ requests/day = $0.50 per million additional requests

## Security

- API key stored as encrypted secret
- HTTPS enforced by default
- CORS headers included for browser compatibility
- No server infrastructure to secure

## Support

- [Cloudflare Workers Docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI Docs](https://developers.cloudflare.com/workers/wrangler/)
- [OpenAI API Docs](https://platform.openai.com/docs/)
