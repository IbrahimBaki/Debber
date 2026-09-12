import type { Metadata, Viewport } from "next";
import { Noto_Sans_Arabic } from "next/font/google";
import "./globals.css";

const arabic = Noto_Sans_Arabic({
  variable: "--font-arabic",
  subsets: ["arabic"],
  weight: ["400", "500", "600", "700", "800"],
});

export const metadata: Metadata = {
  title: {
    default: "لوحة إدارة دبّر",
    template: "%s | لوحة إدارة دبّر",
  },
  description: "وحدة تشغيل داخلية لفريق دبّر فقط.",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ar" dir="rtl" className={`${arabic.variable} h-full antialiased`}>
      <body className="min-h-full bg-neutral-50 text-neutral-900">{children}</body>
    </html>
  );
}
