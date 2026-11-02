# Implementation status — 2 November 2026

Krishi Queue now has a useful offline farmer-assistance layer. It is still a prototype for official procurement operations: no government reservation, eligibility decision, weighbridge measurement or bank transfer is performed by this app.

## Delivered

| Farmer need | Implemented behaviour | Practical limit |
| --- | --- | --- |
| Poor connectivity | Guest access, bundled guidance, locally saved preparation, manual report refresh, no automatic news images in low-data mode | Installation/first download needs connectivity; live sign-in and updates need internet |
| Affordable browser access | A light HTML version before Flutter downloads; 23,101 bytes for its four core files before compression | Browser storage can be cleared/evicted; a paper copy is still useful |
| Understandable interface | Hindi/English core farmer screens, readable type, large touch targets, optional larger text, no decorative emoji | Older practice/operator screens retain English; Chhattisgarhi needs reviewed translations |
| Prepare for procurement | Up to 20 personal visit plans, centre/crop/quantity/date, checklist, optional manually entered official reference and copyable summary | A saved plan does not reserve capacity or queue a booking for automatic submission |
| Shared phones | Farmer/guest-scoped storage, clear-plan confirmation, explicit sign-out and no stored chat transcript | Device plans are local convenience records, not encrypted official evidence or a cloud backup |
| Immediate help | Offline Hindi/English answers about preparation, tokens, payment delays, weighing, fraud and expert referrals | Deterministic topic matching, not live AI, crop diagnosis or official status |
| Human and official assistance | Searchable guides, official links, call buttons and complaint evidence instructions | No automatic complaint submission, centre phone directory or staffed support desk |
| Personal follow-ups | Offline problem notebook, evidence checklist, dated history, farmer-entered official reference, open/resolved filters, due dates on home, copyable summary and owner-scoped deletion | Personal notes only: no filing, official verification, phone alarm or notification to an office; up to 30 notes and 30 history entries per note |
| Sign-in | Google and phone OTP code, Hindi digits, resend cooldown, bounded waits, session restoration and claims-based operator roles | Google OAuth clients, fingerprints, allowed domains and live providers require project setup/testing |
| BHASHINI | Consented Hindi/English text translation through a Firebase-authenticated server gateway | Credentials, production access and deployed endpoint are required; voice is not implemented |
| Market/news information | Chhattisgarh price filter, report dates, cached fallback, manual updates, safe article links and honest storage errors | Live providers are not connected in the default build; reports are not MSP or guaranteed purchase offers |
| Trust in sample workflows | Practice banners on booking/token/queue/payment and operator routes; QR payload explicitly invalid for procurement | All operational booking/payment data remains local sample data |

## Bugs and failure cases addressed

- Wait estimates now count people ahead of the farmer, rather than including the farmer's own service time.
- A booking cannot complete before payment confirmation, or cancel after arrival has entered procurement.
- Token quantities/dates must match their booking; negative queue times and non-finite billing values are rejected.
- Staff practice workflow accepts self-arranged transport; an assigned driver still needs recorded arrival.
- Late authentication restoration cannot reopen an old session after guest entry or sign-out.
- Draft writes are serialized, retries do not duplicate a plan, corruption is not silently overwritten, and storage failures keep edits available.
- Editing is blocked while a save is pending; clipboard failures do not lose the form. Stored crop/date values and Hindi quantity input are handled safely.
- Small-screen and large-text dialog overflows were fixed. News tabs mount only when opened, and shared HTTP clients are disposed.
- Secrets and private booking/payment context no longer go directly from the client to model providers. Online requests are bounded and quota limited; public helplines can be translated while personal-number patterns are rejected.
- Online failures now distinguish missing setup, sign-in requirements, rejected input, usage limits and network problems in Hindi/English. Cached news keeps its saved date visible after a failed refresh.
- The follow-up notebook preserves edits on failed writes, freezes input while saving, keeps account/guest stores separate, handles denied clipboard access and preserves a full history when a farmer marks a note resolved. Deletion is explicitly separate from official complaint withdrawal and visit-plan deletion.

## Verification

- Flutter analysis: no issues on the checked combined source.
- All 78 automated Flutter tests pass, covering authentication/roles, booking/queue invariants, draft persistence and failed writes, local help, cache/parser failures, lazy downloads, self-arranged transport, personal follow-up history/isolation/deletion and 320px screens with doubled text.
- Seven Node tests cover gateway request validation, BHASHINI config/compute and callback restrictions, provider failure and privacy boundaries. Provider responses are mocked.
- Release web build, Android debug APK and optimised Android ARM packages compile successfully. The split packages are about 18 MB for 32-bit ARM and 20 MB for ARM64, compared with the larger universal debug build. They use the repository's existing test signing configuration; even files named `release.apk` are not production-signed store releases.
- Browser check passed at simulated 64 kbit/s download throughput and 800 ms latency. It verified offline reload, persisted plan/checklist, offline answers, deletion, no automatic Flutter download on the landing page, and 320px/2x layout. Login and guest home screenshots were inspected.
- The full Flutter browser flow was also tested as a guest with networking disabled: enter a personal follow-up and a visit plan, scroll each focused form and save to device storage. This caught and fixed text loss in lazily mounted editors; both forms now keep their fields attached while scrolling. Notebook and saved-note screenshots were inspected.

Simulation is not a rural field test. Physical low-cost Android phones, intermittent mobile networks, real OTP delivery, live Google configuration, revoked roles, deployed quotas/rules and actual BHASHINI credentials still need verification.

## What is needed for a real launch

1. **Choose a partner and operating process.** Confirm whether the society, department or authorised integrator will provide data and accept the app's records. Map who updates centre readiness, owns disputes and resolves payment failures.
2. **Connect authoritative records.** Implement server-authorised booking, capacity, verification, receipts and payment reconciliation only against approved APIs. Use server-issued IDs, idempotent requests and audit history. Never promote the local practice repository into a production authority.
3. **Configure optional providers.** Follow [auth setup](AUTH_SETUP.md) and [gateway setup](../functions/README.md). No cloud resources or live authentication settings were changed by this work. Merge and verify quota-access rules before deploying the gateway.
4. **Validate language and assisted access.** Test Hindi wording with farmers; commission or partner for Chhattisgarhi review. Validate BHASHINI production permissions before adding speech; plan an assisted desk, paper/SMS route and delegated consent for farmers without smartphones.
5. **Pilot and measure outcomes.** Compare failed trips, total waiting, sale completion, payment-resolution time and support burden against the centre's baseline. Do not use downloads alone as proof of impact.

## Developer revenue and cost

The implemented free offline layer can support an institution-funded pilot. Potential customers are societies, FPOs, procurement operators or authorised implementation partners paying for setup, training, support and reporting. Payment depends on measurable value and permission to operate; this code does not establish a customer contract or revenue.

Keep basic farmer access free. Price seasonal support, hosting, verification work and optional provider usage separately. Firebase deployment, SMS, online AI and BHASHINI production access may incur costs; a free development quota is not a guarantee of free production. The gateway limits help requests to 30 per signed-in user and 500 globally per UTC day, but quotas are not a billing cap or complete abuse protection. The full problem analysis, adoption evidence and business assumptions remain in the [research report](../RESEARCH_CHHATTISGARH.md).
