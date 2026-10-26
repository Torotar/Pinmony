interface ProductMetadata { products?: Object[]; }
interface ProductSignals {
  is_product_pin?: boolean;
  rich_metadata?: ProductMetadata;
  rich_summary?: ProductMetadata;
  price_value?: number | string;
  price_currency?: string;
}
// Only explicit commerce evidence; ordinary outbound links and descriptions are not product signals.
export function isProductPin(value: Object): boolean {
  const pin: ProductSignals = value as ProductSignals;
  if (!pin) return false;
  if (pin.is_product_pin === true) return true;
  if ([pin.rich_metadata, pin.rich_summary].some((metadata: ProductMetadata | undefined): boolean =>
    Array.isArray(metadata?.products) && metadata!.products!.some((product: Object): boolean =>
      product !== null && typeof product === 'object'))) return true;
  const amount: number = Number(pin.price_value);
  return (typeof pin.price_value === 'number' || typeof pin.price_value === 'string' && /^\d+(?:\.\d+)?$/.test(pin.price_value)) &&
    Number.isFinite(amount) && amount > 0 && typeof pin.price_currency === 'string' && /^[A-Z]{3}$/.test(pin.price_currency);
}
