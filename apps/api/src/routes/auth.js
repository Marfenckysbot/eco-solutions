import { Router } from "express";

const router = Router();

// Authentication must never issue a fabricated token. Replace this safe
// placeholder only when a real identity provider and session validation exist.
router.post("/login", (_req, res) => {
  res.status(503).json({
    error: "Authentication is not configured",
    code: "AUTH_NOT_CONFIGURED"
  });
});

export default router;
