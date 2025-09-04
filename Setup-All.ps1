# ======================================
# Eco Solutions Monorepo Bootstrap (Improved)
# ======================================

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path

function Write-Text {
    param($Path, $Content)
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Set-Content -Path $Path -Value $Content -Force
}

function Test-Command {
    param($cmd)
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$cmd' is not installed or not in PATH." -ForegroundColor Red
        exit 1
    }
}

# Check for required tools
Test-Command npm
Test-Command npx
Test-Command git

Write-Host "Cleaning current structure..." -ForegroundColor Cyan
Remove-Item -Recurse -Force "$root/apps" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/packages" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/.github" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$root/nginx" -ErrorAction SilentlyContinue
Remove-Item -Force "$root/turbo.json","$root/docker-compose.yml","$root/docker-compose.dev.yml" -ErrorAction SilentlyContinue

Write-Host "Creating folders..." -ForegroundColor Cyan
$folders = @(
    "$root/apps/api/src/routes",
    "$root/apps/api/src/models",
    "$root/apps/web/pages/api/auth",
    "$root/apps/web/public",
    "$root/apps/web/components",
    "$root/apps/admin-dashboard/src",
    "$root/packages/payments",
    "$root/nginx"
)
foreach ($f in $folders) { if (-not (Test-Path $f)) { New-Item -ItemType Directory -Path $f | Out-Null } }

# Root package.json
Write-Text "$root/package.json" @'
{
  "name": "eco-solutions",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "concurrently \"npm:start --workspace apps/api\" \"npm:start --workspace apps/web\" \"npm:start --workspace apps/admin-dashboard\""
  },
  "devDependencies": {
    "concurrently": "^8.2.0"
  }
}
'@

# turbo.json
Write-Text "$root/turbo.json" @'
{
  "$schema": "https://turborepo.org/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"]
    },
    "dev": {
      "cache": false
    }
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
  "name": "eco-api",
  "main": "src/server.js",
  "type": "module",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "ioredis": "^5.3.2",
    "mongoose": "^8.0.0",
    "pino": "^8.17.0",
    "pino-http": "^8.6.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
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
    logger.info("MongoDB connected");
    app.listen(PORT, () => logger.info(`API listening on :${PORT}`));
  } catch (err) {
    logger.error({ err }, "Startup error");
    process.exit(1);
  }
}
start();
'@

Write-Text "$root/apps/api/src/models/PetProfile.js" @'
import mongoose from "mongoose";
const PetProfileSchema = new mongoose.Schema({
  ownerEmail: { type: String, required: true, index: true }
}, { timestamps: true });
export default mongoose.model("PetProfile", PetProfileSchema);
'@

Write-Text "$root/apps/api/src/routes/pets.js" @'
import { Router } from "express";
import mongoose from "mongoose";
import Pet from "../models/PetProfile.js";
const r = Router();
function dbReady() { return mongoose.connection?.readyState === 1; }
r.get("/", async (_, res) => {
  if (!dbReady()) return res.status(503).json({ error: "DB not ready" });
  const all = await Pet.find();
  res.json(all);
});
r.post("/", async (req, res) => {
  if (!dbReady()) return res.status(503).json({ error: "DB not ready" });
  const pet = await Pet.create(req.body);
  res.status(201).json(pet);
});
export default r;
'@

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
    headers: { Authorization: `Bearer ${SECRET}`, ...headers }
  });
}
r.post("/initialize", async (req, res) => {
  try {
    const { data } = await paystack().post("/transaction/initialize", req.body);
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
r.get("/verify", async (req, res) => {
  try {
    const { reference } = req.query;
    const { data } = await paystack().get(`/transaction/verify/${reference}`);
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
r.post("/webhook", async (req, res) => {
  // Optionally verify signature here
  res.status(200).send("ok");
});
export default r;
'@

Write-Text "$root/apps/api/src/routes/ai.js" @'
import { Router } from "express";
import axios from "axios";
const r = Router();
const OPENAI_KEY = process.env.OPENAI_API_KEY || "";
r.post("/", async (req, res) => {
  try {
    const { prompt } = req.body;
    const { data } = await axios.post(
      "https://api.openai.com/v1/completions",
      {
        model: "text-davinci-003",
        prompt,
        max_tokens: 100
      },
      { headers: { Authorization: `Bearer ${OPENAI_KEY}` } }
    );
    res.json(data);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});
export default r;
'@

Write-Text "$root/apps/api/src/routes/auth.js" @'
import { Router } from "express";
const r = Router();
r.post("/login", async (req, res) => {
  // Dummy login
  res.json({ token: "dummy-token", user: { email: req.body.email } });
});
export default r;
'@

Write-Text "$root/apps/api/.env.local" @'
PORT=5000
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:5000
MONGO_URI=mongodb://127.0.0.1:27017/eco_petcare
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxx
PAYSTACK_CALLBACK_URL=http://localhost:3000/payment/callback
OPENAI_API_KEY=your_openai_key_here
REDIS_URL=redis://127.0.0.1:6379
'@

# ---------------------------
# apps/web (Next.js)
# ---------------------------
Write-Host "Scaffolding Next.js web app..." -ForegroundColor Cyan
# Use npx to scaffold Next.js app if not present
if (-not (Test-Path "$root/apps/web/package.json")) {
    npx create-next-app@latest apps/web --use-npm --typescript --no-tailwind --no-eslint --no-src-dir --app --import-alias "@/*"
}

# Add .env.local for web
Write-Text "$root/apps/web/.env.local" @'
NEXT_PUBLIC_BACKEND_URL=http://localhost:5000
'@

# ---------------------------
# apps/admin-dashboard (Vite React)
# ---------------------------
Write-Host "Scaffolding admin dashboard..." -ForegroundColor Cyan
Write-Text "$root/apps/admin-dashboard/package.json" @'
{
  "name": "admin-dashboard",
  "main": "src/main.jsx",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^4.4.0"
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
    <title>Eco Admin Dashboard</title>
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
  return <h1>Eco Admin Dashboard</h1>;
}
createRoot(document.getElementById("root")).render(<App />);
'@

# ---------------------------
# packages/payments (shared utils)
# ---------------------------
Write-Host "Scaffolding shared payments package..." -ForegroundColor Cyan
Write-Text "$root/packages/payments/package.json" @'
{
  "name": "payments",
  "main": "index.js",
  "private": true
}
'@

Write-Text "$root/packages/payments/index.js" @'
export function formatNairaKobo(naira) {
  return "₦" + Number(naira).toLocaleString("en-NG", { minimumFractionDigits: 2 });
}
'@

# ---------------------------
# Docker Compose for dev & prod
# ---------------------------
Write-Host "Creating Docker Compose files..." -ForegroundColor Cyan
Write-Text "$root/docker-compose.dev.yml" @'
version: "3.8"
services:
  api:
    build: ./apps/api
    ports:
      - "5000:5000"
    env_file:
      - ./apps/api/.env.local
    volumes:
      - ./apps/api:/app
    command: npm run dev
  web:
    build: ./apps/web
    ports:
      - "3000:3000"
    env_file:
      - ./apps/web/.env.local
    volumes:
      - ./apps/web:/app
    command: npm run dev
  admin-dashboard:
    build: ./apps/admin-dashboard
    ports:
      - "5174:5174"
    volumes:
      - ./apps/admin-dashboard:/app
    command: npm run dev
'@

Write-Text "$root/docker-compose.yml" @'
version: "3.8"
services:
  api:
    build: ./apps/api
    ports:
      - "5000:5000"
    env_file:
      - ./apps/api/.env.local
    command: npm start
  web:
    build: ./apps/web
    ports:
      - "3000:3000"
    env_file:
      - ./apps/web/.env.local
    command: npm start
  admin-dashboard:
    build: ./apps/admin-dashboard
    ports:
      - "5174:5174"
    command: npm start
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
      proxy_pass http://api:5000;
    }
  }
}
'@

# ---------------------------
# Install dependencies
# ---------------------------
Write-Host "Installing dependencies..." -ForegroundColor Cyan
Push-Location "$root"
npm install
Push-Location "$root/apps/api"
npm install
Pop-Location
Push-Location "$root/apps/web"
npm install
Pop-Location
Push-Location "$root/apps/admin-dashboard"
npm install
Pop-Location

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
if (-not (Test-Path $workflowDir)) { New-Item -ItemType Directory -Path $workflowDir | Out-Null }

Write-Text "$workflowDir/deploy.yml" @'
name: Deploy Eco Solutions

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Vercel Deploy
        run: curl -X POST "$VERCEL_DEPLOY_HOOK"
        env:
          VERCEL_DEPLOY_HOOK: ${{ secrets.VERCEL_DEPLOY_HOOK }}
      - name: Trigger Render Deploy
        run: curl -X POST "$RENDER_DEPLOY_HOOK"
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
if (-not (Test-Path "$root/.git")) {
    git init
}
if (-not (git branch --list main)) {
    git checkout -b main
} else {
    git checkout main
}
$repoUrl = "https://github.com/Marfenckysbot/eco-solutions.git"
if (-not (git remote | Where-Object { $_ -eq "origin" })) {
    git remote add origin $repoUrl
}
git add .
git commit -m "Initial monorepo setup"
git push -u origin main