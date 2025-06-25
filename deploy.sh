#!/usr/bin/env sh
# Simple deployment script for the Cloudflare Worker

set -e

echo "🚀 Deploying Cheat CLI Worker..."

# Check if wrangler is installed
if ! command -v wrangler >/dev/null 2>&1; then
    echo "❌ Wrangler CLI not found. Install with: npm install -g wrangler"
    exit 1
fi

# Check if user is logged in
if ! wrangler whoami >/dev/null 2>&1; then
    echo "🔐 Please login to Cloudflare: wrangler login"
    exit 1
fi

# Deploy the worker
echo "📦 Deploying worker..."
wrangler deploy

echo "✅ Deployment complete!"
echo "🌍 Your worker is now available globally"
echo ""
echo "Don't forget to set your OpenAI API key:"
echo "  wrangler secret put OPENAI_API_KEY"
