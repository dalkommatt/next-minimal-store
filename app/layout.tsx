import "./globals.css";
import { Metadata, Viewport } from "next";
import { CartProvider } from "@/components/cart-context";
import { Playfair_Display } from "next/font/google";

export const metadata: Metadata = {
  title: "PAVALTI",
  description: "Classy and chic.",
};

export const viewport: Viewport = {
  themeColor: "#FFFFFF",
};
sd
const playfairDisplay = Playfair_Display({
  subsets: ["latin"],
  weight: "400",
});

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={`${playfairDisplay.className}`}>
        <CartProvider>
          <div className="flex flex-col min-h-screen h-screen mx-5 overflow-y-scroll">
            {children}
          </div>
        </CartProvider>
      </body>
    </html>
  );
}
