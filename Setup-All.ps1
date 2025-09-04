# ======================================
# Eco Solutions Monorepo Bootstrap
# Part 1: Folder creation + root files
# ======================================

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path

function Write-Text {
    param([string]$Path,[string]$Content)
    $dir = Split-Path $Path
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8 -NoNewline
}

Write-Host "Cleaning current structure..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$root/apps" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/packages" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/.github" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/nginx" -ErrorAction SilentlyContinue
Remove-Item -Force "$root/turbo.json","$root/docker-compose.yml","$root/docker-compose.dev.yml" -ErrorAction SilentlyContinue

Write-Host "Creating folders..." -ForegroundColor Cyan
$folders = @(
    "apps/web/pages/api/auth",
    "apps/web/public",
    "apps/web/components",
    "apps/admin-dashboard/src",
    "apps/api/src/controllers",
    "apps/api/src/models",
    "apps/api/src/routes",
    "packages/payments",
    ".github/workflows",
    "nginx"
)

foreach ($f in $folders) {
    $fullPath = Join-Path $root $f
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}

# Root package.json
Write-Text "$root/package.json" @'
{
  "name": "eco-solutions",
  "private": true,
  "version": "1.0.0",
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev": "turbo run dev --parallel",
    "dev:web": "turbo run dev --filter=@eco/web",
    "dev:api": "turbo run dev --filter=@eco/api",
    "dev:admin": "turbo run dev --filter=@eco/admin-dashboard",
    "build": "turbo run build"
  },
  "devDependencies": {
    "turbo": "^2.5.6"
  }
}
'@

# turbo.json
Write-Text "$root/turbo.json" @'
{
  "$schema": "https://turborepo.org/schema.json",
  "pipeline": {
    "dev": { "cache": false, "persistent": true },
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**", ".next/**"] }
  }
}
'@

# .gitignore
Write-Text "$root/.gitignore" @'
node_modules
dist
.next
.env
.env.*
!.env.example
npm-debug.log*
yarn-debug.log*
pnpm-debug.log*
docker-data
'@
# ---------------------------
# apps/api (Express + Mongo + Paystack + AI + Redis + Pino)
# ---------------------------
Write-Host "Scaffolding API..." -ForegroundColor Cyan
Write-Text "$root/apps/api/package.json" @'
{
  "name": "@eco/api",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js"
  },
  "dependencies": {
    "axios": "^1.7.2",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "ioredis": "^5.4.1",
    "mongoose": "^8.5.1",
    "pino": "^9.3.2",
    "pino-http": "^10.3.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.4"
  }
}
'@

Write-Text "$root/apps/api/src/server.js" @'
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import mongoose from "mongoose";
import pino from "pino";
import pinoHttp from "pino-http";
import Redis from "ioredis";
import paymentsRouter from "./routes/payments.js";
import petsRouter from "./routes/pets.js";
import aiRouter from "./routes/ai.js";
import authRouter from "./routes/auth.js";

dotenv.config();
const app = express();
const logger = pino({ level: process.env.LOG_LEVEL || "info" });
app.use(pinoHttp({ logger }));

const FRONTEND = process.env.FRONTEND_URL || "http://localhost:3000";
app.use(cors({ origin: FRONTEND }));
app.use(express.json({ limit: "1mb" }));

// Redis
const REDIS_URL = process.env.REDIS_URL || "redis://127.0.0.1:6379";
const redis = new Redis(REDIS_URL);
redis.on("connect", () => logger.info("Redis connected"));
redis.on("error", (e) => logger.error({ err: e }, "Redis error"));
app.locals.redis = redis;

// Health
app.get("/", (_, res) => res.json({ ok: true, service: "eco-api" }));

// Routes
app.use("/api/auth", authRouter);
app.use("/api/payments", paymentsRouter);
app.use("/api/pets", petsRouter);
app.use("/api/ai", aiRouter);

// DB + Server
const PORT = process.env.PORT || 5000;
const MONGO = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/eco_petcare";

async function start() {
  try {
    await mongoose.connect(MONGO);
    logger.info("Mongo connected");
  } catch (err) {
    logger.error({ err }, "Mongo connection failed");
    console.warn("Continuing without DB. /api/pets & /api/auth need DB.");
  }
  app.listen(PORT, () => logger.info(`API listening on ${PORT}`));
}
start();
'@

# Example PetProfile model
Write-Text "$root/apps/api/src/models/PetProfile.js" @'
import mongoose from "mongoose";
const PetProfileSchema = new mongoose.Schema({
  name: { type: String, required: true },
  species: { type: String, required: true },
  breed: String,
  ageYears: Number,
  weightKg: Number,
  healthConditions: [String],
  ownerEmail: { type: String, required: true, index: true }
}, { timestamps: true });
export default mongoose.model("PetProfile", PetProfileSchema);
'@

# Example pets route
Write-Text "$root/apps/api/src/routes/pets.js" @'
import { Router } from "express";
import mongoose from "mongoose";
import Pet from "../models/PetProfile.js";
const r = Router();
function dbReady() { return mongoose.connection?.readyState === 1; }
r.get("/", async (_, res) => {
  if (!dbReady()) return res.status(503).json({ error: "db_unavailable" });
  const all = await Pet.find().sort({ createdAt: -1 }).limit(100);
  res.json(all);
});
r.post("/", async (req, res) => {
  if (!dbReady()) return res.status(503).json({ error: "db_unavailable" });
  const { name, species, ownerEmail } = req.body || {};
  if (!name || !species || !ownerEmail) return res.status(400).json({ error: "name, species, ownerEmail required" });
  const pet = await Pet.create(req.body);
  res.status(201).json(pet);
});
export default r;
'@

# Example payments route
Write-Text "$root/apps/api/src/routes/payments.js" @'
import { Router } from "express";
import axios from "axios";
import crypto from "crypto";
const r = Router();
const BASE = "https://api.paystack.co";
const SECRET = process.env.PAYSTACK_SECRET_KEY || "";
function paystack(headers = {}) {
  return axios.create({
    baseURL: BASE,
    headers: { Authorization: `Bearer ${SECRET}`, "Content-Type": "application/json", ...headers }
  });
}
r.post("/initialize", async (req, res) => {
  try {
    const { email, amount, metadata } = req.body || {};
    if (!email || !amount) return res.status(400).json({ error: "email and amount required" });
    const callback_url = process.env.PAYSTACK_CALLBACK_URL || `${process.env.BACKEND_URL || "http://localhost:5000"}/api/payments/verify`;
    const { data } = await paystack().post("/transaction/initialize", { email, amount, metadata, callback_url });
    res.json({ authorization_url: data.data.authorization_url, reference: data.data.reference });
  } catch (e) {
    res.status(500).json({ error: "init_failed", details: e.response?.data || e.message });
  }
});
r.get("/verify", async (req, res) => {
  try {
    const ref = req.query.reference;
    if (!ref) return res.status(400).json({ error: "missing reference" });
    const { data } = await paystack().get(`/transaction/verify/${ref}`);
    res.json(data.data);
  } catch (e) {
    res.status(500).json({ error: "verify_failed", details: e.response?.data || e.message });
  }
});
r.post("/webhook", async (req, res) => {
  const signature = req.headers["x-paystack-signature"];
  const payload = JSON.stringify(req.body || {});
  const hash = crypto.createHmac("sha512", SECRET).update(payload).digest("hex");
  if (hash !== signature) return res.status(401).send("invalid signature");
  console.log("Paystack webhook:", req.body?.event, req.body?.data?.reference);
  res.status(200).send("ok");
});
export default r;
'@

# Example AI route
Write-Text "$root/apps/api/src/routes/ai.js" @'
import { Router } from "express";
import axios from "axios";
const r = Router();
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
r.post("/", async (req, res) => {
  try {
    const prompt = req.body?.prompt?.toString()?.slice(0, 2000) || "";
    if (!prompt) return res.status(400).json({ error: "empty prompt" });
    if (!OPENAI_KEY) return res.status(503).json({ error: "missing_openai_key" });
    const { data } = await axios.post(
      "https://api.openai.com/v1/chat/completions",
      {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant for pet care guidance." },
          { role: "user", content: prompt }
        ],
        temperature: 0.4,
        max_tokens: 300
      },
      { headers: { Authorization: `Bearer ${OPENAI_KEY}`, "Content-Type": "application/json" } }
    );
    const reply = data?.choices?.[0]?.message?.content || "No reply";
    res.json({ reply });
  } catch (e) {
    res.status(500).json({ error: "ai_failed", details: e.response?.data || e.message });
  }
});
export default r;
'@

# API .env
Write-Text "$root/apps/api/.env.local" @'
PORT=5000
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:5000
MONGO_URI=mongodb://127.0.0.1:27017/eco_petcare
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxx
PAYSTACK_CALLBACK_URL=http://localhost:3000/payment/callback
OPENAI_API_KEY=your_openai_key_here
# Continue API .env
REDIS_URL=redis://127.0.0.1:6379
'@

# ---------------------------
# apps/admin-dashboard (Vite React)
# ---------------------------
Write-Host "Scaffolding admin dashboard..." -ForegroundColor Cyan
Write-Text "$root/apps/admin-dashboard/package.json" @'
{
  "name": "@eco/admin-dashboard",
  "private": true,
  "version": "1.0.0",
  "scripts": {
    "dev": "vite --port 5174",
    "build": "vite build",
    "preview": "vite preview --port 5174"
  },
  "dependencies": {
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.4.0"
  }
}
'@

Write-Text "$root/apps/admin-dashboard/vite.config.js" @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({ plugins: [react()], server: { port: 5174 } });
'@

Write-Text "$root/apps/admin-dashboard/index.html" @'
<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Eco Admin</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@

Write-Text "$root/apps/admin-dashboard/src/main.jsx" @'
import React from "react";
import { createRoot } from "react-dom/client";
function App() {
  return (
    <div style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>Eco Admin</h1>
      <p>Manage content, users, and subscriptions here.</p>
    </div>
  );
}
createRoot(document.getElementById("root")).render(<App />);
'@

# ---------------------------
# packages/payments (shared utils)
# ---------------------------
Write-Host "Scaffolding shared payments package..." -ForegroundColor Cyan
Write-Text "$root/packages/payments/package.json" @'
{
  "name": "@eco/payments",
  "version": "1.0.0",
  "type": "module",
  "main": "index.js"
}
'@

Write-Text "$root/packages/payments/index.js" @'
export function formatNairaKobo(naira) {
  return Math.round(Number(naira) * 100);
}
'@

# ---------------------------
# Docker Compose for dev & prod
# ---------------------------
Write-Host "Creating Docker Compose files..." -ForegroundColor Cyan
Write-Text "$root/docker-compose.dev.yml" @'
version: "3.8"
services:
  web:
    build: ./apps/web
    ports:
      - "3000:3000"
    volumes:
      - ./apps/web:/app
    environment:
      - NEXT_PUBLIC_BACKEND_URL=http://api:5000
    depends_on:
      - api
  api:
    build: ./apps/api
    ports:
      - "5000:5000"
    volumes:
      - ./apps/api:/app
    environment:
      - MONGO_URI=mongodb://mongo:27017/eco_petcare
      - REDIS_URL=redis://redis:6379
    depends_on:
      - mongo
      - redis
  admin:
    build: ./apps/admin-dashboard
    ports:
      - "5174:5174"
    volumes:
      - ./apps/admin-dashboard:/app
  mongo:
    image: mongo:6
    ports:
      - "27017:27017"
  redis:
    image: redis:7
    ports:
      - "6379:6379"
'@

Write-Text "$root/docker-compose.yml" @'
version: "3.8"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web
      - api
      - admin
  web:
    build: ./apps/web
  api:
    build: ./apps/api
  admin:
    build: ./apps/admin-dashboard
  mongo:
    image: mongo:6
  redis:
    image: redis:7
'@

# Example nginx.conf
Write-Text "$root/nginx/nginx.conf" @'
events {}
http {
  server {
    listen 80;
    location / {
      proxy_pass http://web:3000;
    }
    location /api/ {
      proxy_pass http://api:5000/;
    }
    location /admin/ {
      proxy_pass http://admin:5174/;
    }
  }
}
'@

# ---------------------------
# Install dependencies
# ---------------------------
Write-Host "Installing dependencies..." -ForegroundColor Cyan
if (Get-Command npm -ErrorAction SilentlyContinue) {
  Push-Location $root
  npm install
  Pop-Location
} else {
  Write-Host "npm not found. Please install Node.js (LTS) and rerun." -ForegroundColor Red
  exit 1
}

Write-Host "`n========================================="
Write-Host "Setup complete!"
Write-Host "Update keys in:"
Write-Host "  apps/api/.env.local -> PAYSTACK_SECRET_KEY, OPENAI_API_KEY, MONGO_URI"
Write-Host "  apps/web/.env.local -> NEXT_PUBLIC_BACKEND_URL"
Write-Host "Start dev with: npm run dev"
Write-Host "Frontend -> http://localhost:3000"
Write-Host "Backend  -> http://localhost:5000"
Write-Host "Admin    -> http://localhost:5174"
Write-Host "=========================================" -ForegroundColor Green
# ---------------------------
# GitHub Actions workflow for auto-deploy
# ---------------------------
Write-Host "Creating GitHub Actions workflow for auto-deploy..." -ForegroundColor Cyan

$workflowDir = Join-Path $root ".github/workflows"
if (-not (Test-Path $workflowDir)) {
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
}

Write-Text "$workflowDir/deploy.yml" @'
name: Deploy Eco Solutions

on:
  push:
    branches:
      - main

jobs:
  deploy-web:
    name: Deploy Web to Vercel
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Vercel Deploy Hook
        run: |
          curl -X POST "$VERCEL_DEPLOY_HOOK"
        env:
          VERCEL_DEPLOY_HOOK: ${{ secrets.VERCEL_DEPLOY_HOOK }}

  deploy-api:
    name: Deploy API to Render
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Render Deploy Hook
        run: |
          curl -X POST "$RENDER_DEPLOY_HOOK"
        env:
          RENDER_DEPLOY_HOOK: ${{ secrets.RENDER_DEPLOY_HOOK }}
'@

Write-Host "Workflow created at .github/workflows/deploy.yml" -ForegroundColor Green
Write-Host "Set these secrets in your GitHub repo settings:"
Write-Host " - VERCEL_DEPLOY_HOOK"
Write-Host " - RENDER_DEPLOY_HOOK"

# ---------------------------
# Git init + first push automation
# ---------------------------
Write-Host "Initializing Git repository..." -ForegroundColor Cyan
# Check if 'main' branch exists
if (-not (git branch --list main)) {
    git checkout -b main
} else {
    git checkout main
}
# Use your provided repo URL
$repoUrl = "https://github.com/Marfenckysbot/eco-solutions.git"
if (-not (git branch --list main)) {
    git checkout -b main
} else {
    git checkout main
}


$remoteExists = git remote | Where-Object { $_ -eq "origin" }
if (-not $remoteExists) {
    git remote add origin $repoUrl
    Write-Host "Remote 'origin' set to $repoUrl"
} else {
    Write-Host "Remote 'origin' already exists."
}

try {
    git push -u origin main
    Write-Host "Code pushed to GitHub. If deploy hooks are set, Vercel and Render will start deploying."
} catch {
    Write-Host "Push failed. Make sure your GitHub repo exists and you have permission."
}
