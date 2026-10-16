import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import styles from "./doc.module.css";

export const repo = "https://github.com/v1shalm/cyte";
export const issues = `${repo}/issues`;

export function SiteFooter() {
  return (
    <footer className={styles.footer}>
      <span>© 2026 Cyte</span>
      <nav>
        <Link href="/support">Support</Link>
        <Link href="/privacy">Privacy</Link>
        <Link href="/terms">Terms</Link>
        <a href={repo}>GitHub</a>
      </nav>
    </footer>
  );
}

export function DocPage({ title, updated, lede, children }: { title: string; updated: string; lede: string; children: ReactNode }) {
  return (
    <>
      <header className={styles.nav}>
        <Link className={styles.brand} href="/">
          <Image src="/cyte-icon.png" alt="" width={28} height={28} priority />
          Cyte
        </Link>
        <a className={styles.navCta} href="/downloads/Cyte.dmg" download>
          Download
        </a>
      </header>
      <main className={styles.page}>
        <article className={styles.doc}>
          <p className={styles.updated}>Updated {updated}</p>
          <h1>{title}</h1>
          <p className={styles.lede}>{lede}</p>
          {children}
        </article>
      </main>
      <SiteFooter />
    </>
  );
}
