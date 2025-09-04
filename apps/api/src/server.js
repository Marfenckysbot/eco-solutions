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

// --- MongoDB Connection ---
let mongoConnected = false;
mongoose.connect(process.env.MONGO_URI || "mongodb://127.0.0.1:27017/eco_petcare")
  .then(() => {
    logger.info("✅ Connected to MongoDB");
    mongoConnected = true;
  })
  .catch(err => {
    logger.error({ err }, "❌ MongoDB connection error");
    mongoConnected = false;
  });

// --- Redis Connection ---
let redisConnected = false;
const redis = new Redis(process.env.REDIS_URL || "redis://127.0.0.1:6379");
redis.on("connect", () => {
  logger.info("✅ Connected to Redis");
  redisConnected = true;
});
redis.on("error", (err) => {
  logger.error({ err }, "❌ Redis error");
  redisConnected = false;
});
app.locals.redis = redis;

// --- Health Endpoint ---
app.get("/", (req, res) => {
  res.json({
    ok: true,
    service: "eco-api",
    mongoConnected,
    redisConnected
  });
});

// --- Routes ---
app.use("/api/auth", authRouter);
app.use("/api/payments", paymentsRouter);
app.use("/api/pets", petsRouter);
app.use("/api/ai", aiRouter);

// --- Start Server ---
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => logger.info(`🚀 API listening on :${PORT}`));