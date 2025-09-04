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