# Proposed Decision Register amendment v1.15.0

**Status:** PROPOSED / NON-AUTHORITATIVE / OWNER DECISION PENDING

The current governance router continues to select Decision Register v1.14.0. This proposal is not current authority. Its predecessor is `docs/governance/product/01_DECISIONS_v1.14.0.md`, SHA-256 `d97cb742deefa744279b47686bf5148cceea4b95839fe5b32ad6bbe7d2b6b1fd`.

## Proposed DEC-322 Password-reset message classification and bounded development eligibility

**Status:** PROPOSED / PRODUCT-OWNER DECISION PENDING

Subject to explicit Product-owner acceptance of proposed Product §§21E.23–21E.24, add the narrow `password_reset_message` type for the email that carries Identity-owned password-reset proof to an existing Account. Recommend `editorial_low_risk` for wording only. Identity authentication and security remain HIGH. Preserve the exclusions for `verification_message` and `magic_login_message`, and do not introduce a general transactional-message type.

Content & Media owns the immutable EN/AF message versions and each locale's development-eligibility decision. Identity owns proof, credential, Account and Session truth. Communications owns MessageIntent and delivery. Audit & Evidence owns selected outcome evidence. Product approval of this classification does not approve either exact locale artifact. Content & Media approval of an artifact does not approve the Product classification.

The candidate scope is local development, automated tests, development environments and bounded P8-12 Phase-8 proof. Production, public release, paid pilots, real-participant delivery and Phase 9 remain prohibited. Development eligibility requires the Product extension to be current and attributable Product-owner and Content & Media decisions bound to the exact proposed law and locale artifacts. It creates no runtime role, publication, sender/provider approval, Identity grant or production permission. WELL-91 and its Assent expiry remain unchanged; no authentication-input rebinding is authorised.
