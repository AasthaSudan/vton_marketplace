// What Clothsy needs from a payout rail: a bank transfer to a seller's
// verified account. Amounts are integer paise.

export interface PayoutRequest {
  /// Clothsy's payout id: the idempotency key and the provider reference.
  payoutId: string;
  sellerId: string;
  amount: number;
  accountHolder: string;
  accountNumber: string;
  ifsc: string;
}

export interface SentPayout {
  providerPayoutId: string;
  /// `processed`: the money left; `processing`: the provider confirms later.
  status: 'processed' | 'processing';
  /// Bank reference (UTR) once known.
  utr: string | null;
}

export interface PayoutProvider {
  readonly name: 'razorpayx' | 'mock';
  send(input: PayoutRequest): Promise<SentPayout>;
}
