import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Pool for Mac",
  description:
    "Pool keeps the images, links, notes and X bookmarks you collect, all on your Mac.",
};

export const viewport: Viewport = {
  themeColor: "#F9ED33",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
