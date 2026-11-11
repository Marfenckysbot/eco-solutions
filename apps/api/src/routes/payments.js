import { Router } from "express";

const router = Router();

// Payment collection is intentionally unavailable until server-owned orders,
// amount validation, idempotency and signed webhook verification are implemented.
router.all("*", (_req, res) => {
  res.status(503).json({
    error: "Payments are not enabled",
    code: "PAYMENTS_NOT_CONFIGURED"
  });
});

export default router;
