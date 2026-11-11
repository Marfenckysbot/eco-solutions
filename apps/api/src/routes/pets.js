import { Router } from "express";

const router = Router();

// The previous endpoints exposed every pet record and accepted arbitrary
// writes without authentication or ownership checks. Fail closed until
// authenticated, owner-scoped access is implemented.
router.all("*", (_req, res) => {
  res.status(503).json({
    error: "Pet records are temporarily unavailable",
    code: "PET_API_NOT_CONFIGURED"
  });
});

export default router;
