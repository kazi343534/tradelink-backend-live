# Project Workflow

- Always run `git pull origin main` before starting work, to stay in sync with the latest code.
- Remote repo: `kazi343534/tradelink-backend-live` (DO NOT push/pull from atikxcode/TradeLink)
- Backend runs on Render: `tradelink-backend-live.onrender.com`
- After any backend changes: run `npm run build` in `backend/`, then `git add backend/dist/` before committing (Render runs compiled `dist/` JS, not `src/` TypeScript)