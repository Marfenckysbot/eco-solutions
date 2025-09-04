import mongoose from "mongoose";
const PetProfileSchema = new mongoose.Schema({
  ownerEmail: { type: String, required: true, index: true }
}, { timestamps: true });
export default mongoose.model("PetProfile", PetProfileSchema);
