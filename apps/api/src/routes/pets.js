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
