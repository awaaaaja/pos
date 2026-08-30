// ESC/POS receipt printer — generates printable text for 58mm/80mm thermal printers

export interface ReceiptData {
  storeName: string;
  storeAddress: string;
  storePhone: string;
  invoiceNumber: string;
  date: string;
  cashier: string;
  items: { name: string; qty: number; price: number; subtotal: number }[];
  subtotal: number;
  discount: number;
  tax: number;
  serviceCharge: number;
  total: number;
  paymentMethod: string;
  amountPaid: number;
  change: number;
  loyaltyPoints?: number;
}

export function generateReceipt(data: ReceiptData): string {
  const lines: string[] = [];
  const w = 32; // 58mm width

  const center = (text: string) => {
    const pad = Math.max(0, Math.floor((w - text.length) / 2));
    return " ".repeat(pad) + text;
  };

  const hr = "-".repeat(w);

  lines.push(center(data.storeName));
  lines.push(center(data.storeAddress));
  if (data.storePhone) lines.push(center(data.storePhone));
  lines.push(hr);
  lines.push(`Invoice: ${data.invoiceNumber}`);
  lines.push(`Date:    ${data.date}`);
  lines.push(`Cashier: ${data.cashier}`);
  lines.push(hr);

  for (const item of data.items) {
    lines.push(item.name);
    lines.push(
      `  ${item.qty} x ${fmtNum(item.price)}   ${fmtNum(item.subtotal)}`,
    );
  }

  lines.push(hr);
  lines.push(`Subtotal:      ${fmtNum(data.subtotal)}`);
  if (data.discount > 0) lines.push(`Discount:     -${fmtNum(data.discount)}`);
  if (data.tax > 0) lines.push(`Tax:           ${fmtNum(data.tax)}`);
  if (data.serviceCharge > 0) lines.push(`Service:       ${fmtNum(data.serviceCharge)}`);
  lines.push(hr);
  lines.push(`TOTAL:         ${fmtNum(data.total)}`);
  lines.push(hr);
  lines.push(`Payment: ${data.paymentMethod}`);
  lines.push(`Paid:    ${fmtNum(data.amountPaid)}`);
  lines.push(`Change:  ${fmtNum(data.change)}`);
  if (data.loyaltyPoints && data.loyaltyPoints > 0) {
    lines.push(hr);
    lines.push(`Points earned: +${data.loyaltyPoints}`);
  }
  lines.push(hr);
  lines.push(center("Terima kasih!"));
  lines.push(center("Selamat menikmati"));

  return lines.join("\n");
}

function fmtNum(n: number): string {
  return new Intl.NumberFormat("id-ID", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(n);
}

// Print via Web Bluetooth or USB — sends raw text to thermal printer
export async function printReceipt(text: string): Promise<boolean> {
  try {
    // Try Web Serial API (USB printers)
    if ("serial" in navigator) {
      // ponytail: SerialPort type not in DOM lib, cast via unknown
      const port = await (navigator as { serial?: { requestPort: () => Promise<unknown> } }).serial?.requestPort();
      if (port) {
        const p = port as { open: (opts: { baudRate: number }) => Promise<void>; writable?: { getWriter: () => { write: (data: Uint8Array) => Promise<void>; releaseLock: () => void } }; close: () => Promise<void> };
        await p.open({ baudRate: 9600 });
        const writer = p.writable?.getWriter();
        if (writer) {
          const encoder = new TextEncoder();
          await writer.write(encoder.encode(text));
          await writer.releaseLock();
          await p.close();
          return true;
        }
      }
    }

    // Fallback: open print dialog
    const win = window.open("", "_blank");
    if (win) {
      win.document.write(`<pre style="font-family:monospace;font-size:12px;white-space:pre">${text}</pre>`);
      win.document.close();
      win.print();
      return true;
    }

    return false;
  } catch {
    // Fallback: copy to clipboard
    await navigator.clipboard.writeText(text);
    return false;
  }
}
