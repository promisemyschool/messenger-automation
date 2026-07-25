# Meta App Creation (Messenger Automation)

Focused guide for creating the Meta Developer app and collecting credentials. Webhook registration, n8n deploy, and go-Live steps are separate — see `docs/meta-setup.md` after this.

---

## 1. Create the app

1. Open [Meta for Developers](https://developers.facebook.com/apps/) → **Create App**.
2. Select **Other** → **Business** (or any use case that exposes Messenger).
3. Name the app (e.g. `Promise School Messenger`).
4. Link it to your Business Portfolio if prompted (optional but recommended for org apps).

---

## 2. Add required products

In the app dashboard, click **Add Product** and enable:

| Product | Purpose |
|---------|---------|
| **Messenger** | Connect your Facebook Page and generate a Page Access Token for sending/receiving DMs |
| **Webhooks** | Subscribe to incoming Messenger events (configured later against your n8n URL) |

---

## 3. Permissions

These are the permissions this setup needs. Request or grant them when generating tokens in Graph API Explorer or during App Review.

### Required for token generation (Development)

When getting a User Access Token in [Graph API Explorer](https://developers.facebook.com/tools/explorer/), select:

| Permission | Access level | Why |
|------------|--------------|-----|
| **pages_messaging** | Standard (dev) / **Advanced** (Live) | Send and receive Messenger messages via Graph API (`POST /me/messages`) |
| **pages_manage_metadata** | Standard | Subscribe the Page to your app and manage webhook metadata |
| **pages_show_list** | Standard | List Pages you manage so you can select the correct Page token |

**pages_messaging is the critical one.** Without it, Mark Seen, typing indicators, and reply sends will fail.

### For going Live (later)

In **App Review → Permissions and Features**, request **Advanced Access** for:

- **pages_messaging** — required so non-app-role customers (any Messenger user) receive bot replies

Supporting permissions (`pages_manage_metadata`, `pages_show_list`) usually stay at Standard Access. See `docs/app-review.md` when ready.

### Development vs Live

| App mode | Who the bot can reply to |
|----------|--------------------------|
| **Development** | App admins, developers, testers, and Page roles only |
| **Live** + Advanced Access on pages_messaging | All Messenger users |

---

## 4. Connect your Facebook Page

1. Go to **Messenger → Settings**.
2. Click **Add or Remove Pages**.
3. Connect the Promise School Page using a Facebook account that has the **MESSAGING** task on that Page.
4. Under **Token Generation**, select your Page → click **Generate** → copy the **Page Access Token**.

To get a **long-lived** token (recommended):

1. [Graph API Explorer](https://developers.facebook.com/tools/explorer/) → select your app.
2. **Get User Access Token** → add the three permissions above.
3. **Get Page Access Token** → select your Page.
4. Extend the token via [Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/) if it is short-lived.

---

## 5. Collect credentials for `.env`

From the Meta console, copy these values into `messenger-automation/.env`:

```bash
# App settings → Basic
META_APP_ID=<your-app-id>
META_APP_SECRET=<your-app-secret>

# Messenger → Settings → Token Generation
META_PAGE_ACCESS_TOKEN=<long-lived-page-token>
META_PAGE_ID=<your-page-id>

# Pick any random secret string (same value used later in Webhooks → Verify Token)
META_VERIFY_TOKEN=<random-secret-string>

META_GRAPH_API_VERSION=v22.0
```

- **App ID + App Secret** — used by `./scripts/setup-meta.sh` to auto-subscribe webhook fields.
- **Page Access Token** — used by n8n to call `https://graph.facebook.com/v22.0/me/messages`.
- **Page ID** — identifies which Page receives webhooks.
- **Verify token** — shared secret for Meta webhook verification (not the Page ID or Page token).

Never commit tokens to git. Store secrets only in `.env` on the VPS.

---

## 6. Add testers (Development mode)

While the app stays in **Development**:

1. Go to **App Roles → Roles**.
2. Add your personal Facebook account as **Administrator**, **Developer**, or **Tester**.
3. Only people with these roles (plus Page roles) will receive bot replies until the app goes Live.

---

## Checklist (Meta app only)

- [ ] Meta app created (**Other → Business**)
- [ ] **Messenger** and **Webhooks** products added
- [ ] **App ID** and **App Secret** copied
- [ ] Facebook Page connected under Messenger → Settings
- [ ] Page Access Token generated with `pages_messaging`, `pages_manage_metadata`, `pages_show_list`
- [ ] Token extended to long-lived
- [ ] `META_PAGE_ID`, `META_PAGE_ACCESS_TOKEN`, `META_VERIFY_TOKEN` saved in `.env`
- [ ] Testers added under App Roles (for dev-mode DMs)

**Next steps (outside this guide):** deploy n8n, register webhook callback URL, subscribe Page to `messages` + `messaging_postbacks` — see `docs/meta-setup.md`.
