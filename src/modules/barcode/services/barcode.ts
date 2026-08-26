import JsBarcode from "jsbarcode";
import { jsPDF } from "jspdf";
import { supabase } from "@/services/supabase";

/**
 * Generate a random CODE128-compatible barcode string
 */
export function generateBarcodeValue(): string {
  // CODE128: numeric + uppercase + some symbols, 12 chars
  const chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  let result = "";
  for (let i = 0; i < 12; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

/**
 * Render barcode to a canvas element
 */
export function renderBarcode(canvas: HTMLCanvasElement, value: string): void {
  JsBarcode(canvas, value, {
    format: "CODE128",
    width: 2,
    height: 60,
    displayValue: true,
    fontSize: 14,
    margin: 5,
  });
}

/**
 * Render barcode to an SVG element
 */
export function renderBarcodeToSvg(svg: SVGSVGElement, value: string): void {
  JsBarcode(svg, value, {
    format: "CODE128",
    width: 2,
    height: 60,
    displayValue: true,
    fontSize: 14,
    margin: 5,
  });
}

/**
 * Assign a new barcode to a product
 */
export async function assignBarcode(
  productId: string,
  barcodeValue?: string,
): Promise<{ barcode: string; error: string | null }> {
  const value = barcodeValue || generateBarcodeValue();

  const { error } = await supabase.from("products").update({ barcode: value }).eq("id", productId);

  if (error) return { barcode: "", error: error.message };
  return { barcode: value, error: null };
}

interface BarcodeLabel {
  productName: string;
  barcode: string;
  price?: number;
}

/**
 * Generate PDF with barcode labels
 * @param labels - array of { productName, barcode, price }
 * @param opts - label size options
 */
export function generateBarcodeLabelsPdf(
  labels: BarcodeLabel[],
  opts?: {
    labelWidth?: number; // mm
    labelHeight?: number; // mm
    cols?: number;
    rows?: number;
  },
): void {
  const labelW = opts?.labelWidth ?? 50;
  const labelH = opts?.labelHeight ?? 30;
  const cols = opts?.cols ?? 4;

  const doc = new jsPDF({
    orientation: "portrait",
    unit: "mm",
    format: "a4",
  });

  const pageW = 210;
  const pageH = 297;
  const marginX = (pageW - cols * labelW) / 2;
  const marginY = 10;

  let x = marginX;
  let y = marginY;
  let count = 0;

  for (const label of labels) {
    // Draw label border
    doc.setDrawColor(200);
    doc.setLineWidth(0.3);
    doc.roundedRect(x, y, labelW, labelH, 2, 2);

    // Product name (truncated)
    doc.setFontSize(7);
    doc.setFont("helvetica", "bold");
    const name =
      label.productName.length > 20 ? label.productName.slice(0, 18) + ".." : label.productName;
    doc.text(name, x + 2, y + 5);

    // Generate barcode image
    const barcodeCanvas = document.createElement("canvas");
    JsBarcode(barcodeCanvas, label.barcode, {
      format: "CODE128",
      width: 1.5,
      height: 30,
      displayValue: true,
      fontSize: 8,
      margin: 0,
    });

    const barcodeDataUrl = barcodeCanvas.toDataURL("image/png");
    doc.addImage(barcodeDataUrl, "PNG", x + 2, y + 7, labelW - 4, 14);

    // Price
    if (label.price !== undefined) {
      doc.setFontSize(7);
      doc.setFont("helvetica", "normal");
      const priceStr = `Rp${label.price.toLocaleString("id-ID")}`;
      doc.text(priceStr, x + 2, y + labelH - 3);
    }

    count++;
    x += labelW;

    if (count % cols === 0) {
      x = marginX;
      y += labelH;
    }

    if (y + labelH > pageH - marginY) {
      doc.addPage();
      y = marginY;
    }
  }

  doc.save("barcode-labels.pdf");
}
