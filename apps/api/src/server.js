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