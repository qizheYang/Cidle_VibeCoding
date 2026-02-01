# Cidle Secure Deployment Guide

This guide explains how to deploy Cidle with secure API key handling.

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│  Flutter Web    │────▶│  Cloudflare Worker   │────▶│  OpenAI API │
│  (GitHub Pages) │     │  (holds API key)     │     │             │
└─────────────────┘     └──────────────────────┘     └─────────────┘
```

Your OpenAI API key is stored securely in Cloudflare and never exposed to the browser.

## Step 1: Deploy the Cloudflare Worker

### Prerequisites
- A [Cloudflare account](https://dash.cloudflare.com/sign-up) (free tier works)
- Node.js installed
- Your OpenAI API key

### Deploy

```bash
# Navigate to the worker directory
cd cloudflare-worker

# Install Wrangler CLI (Cloudflare's tool)
npm install -g wrangler

# Login to Cloudflare
npx wrangler login

# Deploy the worker
npx wrangler deploy

# Add your OpenAI API key as a secret (it will prompt for the value)
npx wrangler secret put OPENAI_API_KEY
```

After deployment, you'll get a URL like:
```
https://cidle-api.<your-subdomain>.workers.dev
```

### (Optional) Custom Domain

If you want to use a custom domain like `api.yangqizhe.com`:

1. Go to Cloudflare Dashboard → Workers & Pages → your worker
2. Click "Triggers" tab
3. Add a custom domain

## Step 2: Build Flutter Web with Proxy URL

Build the Flutter app with your worker URL:

```bash
# Replace with your actual worker URL
flutter build web --dart-define=PROXY_URL=https://cidle-api.your-subdomain.workers.dev
```

## Step 3: Deploy to GitHub Pages

```bash
# Copy build output to your GitHub Pages repo
cp -r build/web/* /path/to/qizheYang.github.io/game/cidle/

# Commit and push
cd /path/to/qizheYang.github.io
git add .
git commit -m "Update Cidle"
git push
```

## Security Notes

1. **API Key Safety**: Your OpenAI key is stored in Cloudflare's secret storage, not in any public code
2. **CORS**: The worker allows all origins by default. For production, edit `worker.js` and change:
   ```javascript
   'Access-Control-Allow-Origin': 'https://yangqizhe.com'
   ```
3. **Rate Limiting**: Consider adding rate limiting to prevent abuse. See [Cloudflare Rate Limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limiting/)

## Fallback Mode

If you don't deploy the worker (or `PROXY_URL` is empty), the game still works with:
- Hardcoded word lists (620+ words, 100+ idioms)
- MDBG.net API for pinyin lookup
- No AI-generated hints

## Troubleshooting

### Worker not responding
```bash
# Check worker logs
npx wrangler tail
```

### API key not working
```bash
# Re-add the secret
npx wrangler secret put OPENAI_API_KEY
```

### CORS errors
Make sure your domain is allowed in the worker's `corsHeaders`.

## Costs

- **Cloudflare Workers**: Free tier includes 100,000 requests/day
- **OpenAI API**: Pay per use (~$0.002 per 1K tokens for GPT-3.5-turbo)

For a game with moderate usage, expect costs under $1/month.
