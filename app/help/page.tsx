import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Help - PAVALTI",
  description: "Help and support information for PAVALTI.",
};

export default function HelpPage() {
  return (
    <div className="mt-12 space-y-12  max-w-[700px] mx-auto">
      <h1 className="text-xl">HELP</h1>

      <section className="space-y-4">
        <h2 className="text-lg">ALL SALES FINAL</h2>
        <p className="leading-relaxed">
          All sales are final due to the low cost of goods. We do not offer
          returns, exchanges, or refunds. Please review your order carefully
          before completing your purchase.
        </p>
      </section>

      <section className="space-y-4">
        <h2 className="text-lg">ORDER ISSUES</h2>
        <p className="leading-relaxed">
          For any issues with your order (e.g., wrong item or defective
          product), contact us at help@pavalti.com
        </p>
        <p className="leading-relaxed">
          Please include your order number and details of the issue.
        </p>
      </section>
    </div>
  );
}
