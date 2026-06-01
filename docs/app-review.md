# Meta App Review (go Live for all users)

Use this checklist when Development-mode testing is complete.

## Permission to request

- **`pages_messaging`** — Advanced Access (required for replying to customers who are not app roles)

Supporting permissions (usually standard access):

- `pages_manage_metadata`
- `pages_show_list`

## Before submitting

1. Bot answers FAQ accurately (app free, Hobbycamp paid, NCTB classes 6–12, etc.).
2. Escalation works for refunds, account issues, payment disputes → `support@promiseschool.com`.
3. Privacy policy is linked: https://promiseschool.com/privacy-policy
4. Page About or first message mentions AI-assisted support (recommended).

## Test script for screencast

Record a 2–3 minute video showing:

1. User messages Promise School Page: "Is the app free?"
2. Bot replies accurately in English.
3. User messages in Bangla: "হবিক্যাম্প কি?"
4. Bot replies in Bangla with Hobbycamp link.
5. User asks: "I need a refund" → bot escalates to support email.

## Submission steps

1. Meta Developer Console → **App Review → Permissions and Features**.
2. Request **Advanced Access** for `pages_messaging`.
3. Provide:
   - Use case: customer support for Promise School learning app and Hobbycamp
   - Webhook URL (production n8n URL)
   - Screencast URL (unlisted YouTube or Loom)
4. Answer: bot only uses approved FAQ knowledge; sensitive topics escalate to humans.

## After approval

1. Switch app to **Live** mode (top of dashboard).
2. Message the Page from a non-admin Facebook account to confirm replies work.
3. Monitor n8n **Executions** for 1–2 weeks; tune prompts if answers drift.

## Rollback

- Deactivate n8n workflow → Meta webhooks still deliver but no auto-reply
- Or remove Page subscription: Meta → Messenger → Webhooks → unsubscribe Page
