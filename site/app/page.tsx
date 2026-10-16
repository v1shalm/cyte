import Image from "next/image";
import styles from "./page.module.css";

const tiles = [
  [{ h: 92, tone: "dark" }, { h: 60, tone: "white" }, { h: 76, tone: "blue" }],
  [{ h: 64, tone: "white" }, { h: 104, tone: "sand" }, { h: 56, tone: "white" }],
  [{ h: 80, tone: "blue" }, { h: 70, tone: "dark" }, { h: 84, tone: "white" }],
];

export default function Home() {
  return (
    <main className={styles.page}>
      <section className={styles.hero}>
        <Image
          className={styles.icon}
          src="/pool-icon.png"
          alt=""
          width={104}
          height={104}
          priority
        />
        <h1 className={styles.title}>Your saves, in one place.</h1>
        <p className={styles.lede}>
          Cyte keeps the images, links, notes and X bookmarks you collect on your Mac. It reads
          each one on the device, so search finds a poster by the words printed on it.
        </p>
        <a className={styles.download} href="/downloads/Pool.dmg" download>
          <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
            <path
              d="M8 2v8.2m0 0L4.6 6.8M8 10.2l3.4-3.4M3 13.5h10"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          Download for Mac
        </a>
        <p className={styles.meta}>Free · macOS 26 or later · Apple silicon · 3.8 MB</p>
        <p className={styles.note}>
          First launch: open System Settings → Privacy &amp; Security and choose Open Anyway.
        </p>
      </section>

      <div className={styles.window} aria-hidden="true">
        <div className={styles.lights}>
          <span />
          <span />
          <span />
        </div>
        <div className={styles.sidebar}>
          <span className={styles.sideLabel} />
          <span className={styles.sideActive} />
          <span className={styles.sideLine} />
          <span className={styles.sideLine} />
        </div>
        <div className={styles.canvas}>
          <div className={styles.toolbar}>
            <span className={styles.search} />
            <span className={styles.tabs}>
              <span className={styles.tabActive} />
              <span className={styles.tab} />
              <span className={styles.tab} />
            </span>
          </div>
          <div className={styles.grid}>
            {tiles.map((column, c) => (
              <div className={styles.column} key={c}>
                {column.map((tile, t) => (
                  <span
                    key={t}
                    className={`${styles.tile} ${styles[tile.tone]}`}
                    style={{ height: tile.h }}
                  />
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}
