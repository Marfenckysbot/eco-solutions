import { Router } from "express";

const router = Router();

// Do not expose an unauthenticated, unmetered legacy model endpoint.
// Enable AI only after provider selection, request validation, authentication,
// rate limiting and spending controls are implemented.
router.all("*", (_req, res) => {
  res.status(503).json({
    error: "AI assistance is not configured",
    code: "AI_NOT_CONFIGURED"
  });
});

export default router;
