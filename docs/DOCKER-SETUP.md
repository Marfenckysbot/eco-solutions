# Docker setup

The Compose files run the API, static admin dashboard, MongoDB and Redis. The old web service was removed because `apps/web` does not exist in this repository.

## Local preview

```sh
docker compose -f docker-compose.dev.yml up --build
```

- API health endpoint: `http://localhost:5000/`
- Admin dashboard: `http://localhost:5174/`

The current API deliberately disables placeholder authentication, payment, pet-record and AI routes until secure implementations are completed. Docker Compose does not make those integrations production-ready. Do not expose this stack publicly or use it for real customer records or payments.
