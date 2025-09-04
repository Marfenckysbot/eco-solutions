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