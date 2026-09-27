# Clothsy Shop App — Phase 3: Accounts, Checkout, Payments and Orders

## Goal
Turn the browsing app into a transacting app: authentication, addresses, checkout, payments, order tracking, profile and notifications.

## Depends On
Phase 2 cart and product data layer.

## Authentication
- Sign in with phone OTP (primary for India), Google, and Apple (required on iOS if any social login exists).
- Email + password as a fallback.
- Map auth to Shopify Customer Account API so orders and addresses live against the customer.
- Guest browsing allowed; login is prompted only at checkout, wishlist sync, or try-on history.
- Tokens stored in secure storage, refreshed automatically by a Dio interceptor; forced logout on refresh failure.
- Router redirect guards for protected routes.
- On login, merge guest cart and guest wishlist into the account.

## Addresses
- Address list, add, edit, delete, set default.
- PIN code lookup to auto-fill city/state.
- Serviceability check by PIN code before payment.

## Checkout Flow
1. Cart review
2. Address selection
3. Delivery option and estimated delivery date
4. Payment method
5. Order summary and place order
6. Success screen with order number and "Track order"

Decision: two viable paths.
- Fastest: Shopify hosted checkout inside an in-app web view. Least work, Shopify handles taxes, discounts and payments.
- Best UX (recommended once volume justifies it): native checkout screens, order created via backend, payment via Razorpay native SDK.
Start with hosted checkout to ship; move to native in a later iteration.

## Payments
- Razorpay for UPI, cards, net banking, wallets; Cash on Delivery as an option.
- Payment success is confirmed only by server-side webhook verification, never by the client callback alone.
- Handle failure, cancellation and pending states with clear retry.
- Idempotency on order creation to avoid duplicate orders on retries.

## Orders
- Order list with status chips (Placed, Packed, Shipped, Out for delivery, Delivered, Cancelled, Returned).
- Order detail: items, address, payment summary, invoice download.
- Tracking timeline (vertical stepper) fed by the shipping partner status.
- Cancel (before shipping) and return/exchange request flows.
- Reorder button.

## Profile
- Header with name, avatar, phone/email.
- Sections: Orders, Addresses, Wishlist, Saved try-on photos (Phase 4), Notifications, Language, Help and Support, Privacy, Terms, Log out, Delete account (store-policy requirement).
- Edit profile.

## Notifications
- Firebase Cloud Messaging for order updates, price drops on wishlist items, back-in-stock alerts and campaigns.
- In-app notification centre.
- Notification tap deep-links to the relevant order or product.
- Permission prompt shown after first order or first wishlist action, not on launch.

## Backend Requirements (small service alongside Shopify)
- Webhook receiver for payment and order events.
- Push notification dispatch.
- Any logic Shopify cannot do directly (custom offers, try-on credits in Phase 4).
- Recommended: a lightweight FastAPI or Supabase Edge Functions service.

## Security
- No payment keys or admin tokens in the app binary; only public storefront tokens.
- Certificate pinning on the custom backend.
- Rate limiting on OTP requests.
- Personal data encrypted at rest on device.

## Deliverables
1. Auth (OTP, Google, Apple) with guest-to-account merge.
2. Address management with PIN serviceability.
3. Working checkout with Razorpay and COD.
4. Orders list, detail, tracking, cancel and return.
5. Profile and settings.
6. Push notifications with deep links.
7. Integration tests for full purchase flow in the staging flavor.

## Acceptance Criteria
- A new user can install, browse, log in, pay and see the order in under 3 minutes.
- No duplicate orders under network retry or app kill during payment.
- Order status updates arrive as push notifications within a minute of the backend event.
- Account deletion works end to end.
