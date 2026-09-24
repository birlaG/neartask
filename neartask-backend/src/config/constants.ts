// Business rules from PRD §6.6. Kept as env-driven config, not hardcoded,
// so they can be tuned without a code deploy (per the PRD's explicit guidance).

export const getPlatformCommissionPercent = (): number =>
  Number(process.env.PLATFORM_COMMISSION_PERCENT ?? 12);

export const getPreAcceptRefundPercent = (): number =>
  Number(process.env.PRE_ACCEPT_REFUND_PERCENT ?? 95);
