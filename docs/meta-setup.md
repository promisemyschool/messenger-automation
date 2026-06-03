# Meta Developer App setup (Promise School Messenger)

Follow these steps once. Store secrets only in `messenger-automation/.env` on the VPS and in n8n credentials — never commit tokens.

## 1. Create the Meta app

1. Open [Meta for Developers](https://developers.facebook.com/apps/) and click **Create App**.
2. Choose **Other** → **Business** (or the type that exposes Messenger).
3. Name it e.g. `Promise School Messenger`.
4. Add products:
   - **Messenger**
   - **Webhooks**

## 2. Connect the Promise School Facebook Page

1. In **Messenger → Settings**, click **Add or Remove Pages**.
2. Connect the Promise School Page with a Facebook account that has the **MESSAGING** task on that Page.
3. Generate a **Page Access Token** and copy it into `.env`:

```bash
META_PAGE_ACCESS_TOKEN=your-long-lived-page-token
META_PAGE_ID=your-page-id
```

### Long-lived Page token

1. [Graph API Explorer](https://developers.facebook.com/tools/explorer/)
2. Select your app → **Get User Access Token** with:
   - `pages_manage_metadata`
   - `pages_messaging`
   - `pages_show_list`
3. **Get Page Access Token** → select Promise School Page.
4. Extend to long-lived token if needed via [Access Token Debugger](https://developers.facebook.com/tools/debug/accesstoken/).

## 3. Configure the verify token

Pick a random secret string:

```bash
META_VERIFY_TOKEN=promise-school-messenger-verify-CHANGE-ME
```

Use the **same value** in:

- `messenger-automation/.env`
- Meta Developer Console → Webhooks → Verify Token

## 4. Configure the webhook (after VPS deploy)

1. Deploy the stack (`./scripts/deploy.sh`) and import the n8n workflow — see [`n8n-webhook-setup.md`](n8n-webhook-setup.md).
2. **Publish** the workflow in n8n (webhook path must be `messenger`, GET + POST).
3. On the VPS, ensure `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` in `.env`, then:

   ```bash
   docker compose up -d --force-recreate n8n
   ```

4. Run the curl gate **before** Meta verify:

   ```bash
   ./scripts/verify-webhook.sh
   ```

   Success: response body is exactly `hello_meta_test` (or your `WEBHOOK_VERIFY_CHALLENGE`).  
   Failure: empty body or 404 — do not use Meta **Verify and save** until this passes.

5. In Meta → **Messenger → Webhooks** (or Webhooks product):
   - **Callback URL:** `https://<your-domain>/webhook/messenger` (must match n8n **Production URL**)
   - **Verify token:** value of `META_VERIFY_TOKEN` (not Page ID)
6. Click **Verify and save**.
7. Subscribe to webhook fields: **`messages`**, **`messaging_postbacks`**.

### Webhook path mistakes

| Mistake | Symptom |
|---------|---------|
| Path set to a UUID instead of `messenger` | Meta URL `/webhook/messenger` returns 404 |
| GET only (no POST) | Meta messages fail after verify |
| Wrong verify token vs `.env` | HTTP 200 but empty body; Meta verify fails |
| Workflow not published | 404 `not registered` |

## 5. Subscribe the Page to your app

After `.env` is filled:

```bash
cd messenger-automation
chmod +x scripts/setup-meta.sh
./scripts/setup-meta.sh
```

## 6. Development vs Live mode

| Mode | Who gets bot replies |
|------|----------------------|
| **Development** | App admins, developers, testers, and Page roles only |
| **Live** + Advanced Access | All Messenger users |

For internal testing, keep the app in **Development** and add testers under **App Roles → Roles**.

## Checklist

- [ ] Meta app created with Messenger + Webhooks
- [ ] Promise School Page connected
- [ ] `META_PAGE_ACCESS_TOKEN` in `.env`
- [ ] `META_PAGE_ID` in `.env`
- [ ] `META_VERIFY_TOKEN` matches Meta console
- [ ] n8n workflow imported, path `messenger`, **Published**
- [ ] `./scripts/verify-webhook.sh` passes
- [ ] Webhook verified in Meta console
- [ ] `./scripts/setup-meta.sh` completed successfully

Next: [VPS deploy](vps-deploy.md) → [App Review](app-review.md)
