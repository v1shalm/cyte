import Image from "next/image";
import { AppWindow } from "./appwindow";
import { SiteFooter } from "./doc";
import { Icon, type IconName } from "./icons";
import styles from "./page.module.css";

const features: { icon: IconName; title: string; body: string; demo: "motion" | "text" | "select" | "smart" | "similar" | "x" }[] = [
  {
    icon: "play",
    title: "Videos and GIFs play in the grid",
    body: "Saved videos and GIFs loop on their own as you scroll. Open one to hear it, scrub through it or pause it.",
    demo: "motion",
  },
  {
    icon: "scan",
    title: "Search the words inside images",
    body: "Cyte reads every image on your Mac. Type kerning and the poster that says it comes up.",
    demo: "text",
  },
  {
    icon: "tick",
    title: "Select many, act once",
    body: "Shift-click a range, then tag, file or delete it together. Deleting and filing both keep an undo.",
    demo: "select",
  },
  {
    icon: "sparkles",
    title: "Smart folders",
    body: "Save any filter as a folder that fills itself when new saves match.",
    demo: "smart",
  },
  {
    icon: "similar",
    title: "Find similar",
    body: "Right-click an image to see the saves that look like it, matched on your device.",
    demo: "similar",
  },
  {
    icon: "bookmark",
    title: "X bookmarks, kept apart",
    body: "Import bookmarked posts with images or videos. They get their own place and stay out of Everything.",
    demo: "x",
  },
];

const keys: [string, string][] = [
  ["⌘K", "Search"],
  ["⌃⌥ Space", "Search from anywhere"],
  ["⌥⌘P", "Save the page in your browser"],
  ["T", "Tag"],
  ["F", "Add to folder"],
  ["X", "Select"],
  ["Space", "Open"],
  ["⌘A", "Select all"],
];

function Demo({ kind }: { kind: (typeof features)[number]["demo"] }) {
  switch (kind) {
    case "motion":
      return (
        <div className={styles.demo}>
          <div className={styles.motionTiles}>
            <i style={{ backgroundImage: "linear-gradient(135deg,#ff8a5c,#ff3d7f,#7b5cff,#ff8a5c)" }}>
              <b />
            </i>
            <i style={{ backgroundImage: "linear-gradient(135deg,#2bd2a5,#2563eb,#111319,#2bd2a5)" }}>
              <b />
            </i>
          </div>
        </div>
      );
    case "text":
      return (
        <div className={styles.demo}>
          <div className={styles.miniSearch}>
            <Icon name="search" size={13} />
            <span>kerning</span>
          </div>
          <div className={styles.hitRow}>
            <span className={`${styles.hit} ${styles.hitA}`}>
              <em>Kerning</em>
            </span>
            <span className={`${styles.hit} ${styles.hitB}`}>
              <em>kerning pairs</em>
            </span>
          </div>
        </div>
      );
    case "select":
      return (
        <div className={styles.demo}>
          <div className={styles.bar}>
            <span className={styles.barClose}>
              <Icon name="cancel" size={11} />
            </span>
            <b>3 selected</b>
            <span className={styles.split}>
              <i className={styles.splitFirst}>
                <Icon name="folder" size={12} /> Folder
              </i>
              <i className={styles.splitMid}>
                <Icon name="hash" size={12} /> Tag
              </i>
              <i className={styles.splitLast}>
                <Icon name="trash" size={12} /> Delete
              </i>
            </span>
          </div>
        </div>
      );
    case "smart":
      return (
        <div className={styles.demo}>
          <div className={styles.folder}>
            <span className={styles.folderArt}>
              <Icon name="sparkles" size={20} />
            </span>
            <b>Type · Images</b>
            <em>38 saves</em>
          </div>
        </div>
      );
    case "similar":
      return (
        <div className={styles.demo}>
          <div className={styles.thumbs}>
            <i style={{ background: "linear-gradient(160deg,#1d2cf0,#7b5cff)" }} />
            <i style={{ background: "linear-gradient(160deg,#3a4cf5,#9a85ff)" }} />
            <i style={{ background: "linear-gradient(160deg,#5160f7,#b7a9ff)" }} />
            <i style={{ background: "linear-gradient(160deg,#6c78f9,#cfc6ff)" }} />
          </div>
        </div>
      );
    case "x":
      return (
        <div className={styles.demo}>
          <div className={styles.railMini}>
            <span>
              <Icon name="grid" size={18} />
            </span>
            <span className={styles.railMiniOn}>
              <Icon name="bookmark" size={18} />
            </span>
            <span>
              <Icon name="folder" size={18} />
            </span>
          </div>
        </div>
      );
  }
}

export default function Home() {
  return (
    <>
      <header className={styles.nav}>
        <a className={styles.brand} href="#top">
          <Image src="/cyte-icon.png" alt="" width={28} height={28} priority />
          Cyte
        </a>
        <nav className={styles.navLinks}>
          <a href="#features">Features</a>
          <a href="#keyboard">Keyboard</a>
          <a className={styles.navCta} href="/downloads/Cyte.dmg" download>
            Download
          </a>
        </nav>
      </header>

      <main id="top" className={styles.page}>
        <section className={styles.hero}>
          <h1 className={styles.title}>
            Save anything.
            <br />
            <span>Find it in seconds.</span>
          </h1>
          <p className={styles.lede}>
            Cyte keeps the images, links, notes and X bookmarks you collect in one calm grid on your Mac. It reads
            every image on your device, so you can search a poster by the words printed on it.
          </p>
          <div className={styles.pair}>
            <a className={styles.primary} href="/downloads/Cyte.dmg" download>
              <Icon name="download" size={16} />
              Download for Mac
            </a>
            <a className={styles.secondary} href="https://github.com/v1shalm/cyte">
              <Icon name="github" size={16} />
              GitHub
            </a>
          </div>
          <p className={styles.meta}>Free · macOS 26 or later · Apple silicon</p>
        </section>

        <div className={styles.stage}>
          <AppWindow />
        </div>

        <section id="features" className={styles.section}>
          <h2 className={styles.h2}>
            Everything you save,
            <br />
            one calm grid.
          </h2>
          <div className={styles.bento}>
            {features.map((f) => (
              <article className={styles.card} key={f.title}>
                <Demo kind={f.demo} />
                <div className={styles.cardText}>
                  <span className={styles.cardIcon}>
                    <Icon name={f.icon} size={16} />
                  </span>
                  <h3>{f.title}</h3>
                  <p>{f.body}</p>
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className={styles.stats}>
          <div>
            <b>10,000</b>
            <span>saves in the largest library we tested</span>
          </div>
          <div>
            <b>83 ms</b>
            <span>to open all of them from the index</span>
          </div>
          <div>
            <b>0</b>
            <span>servers that see your library</span>
          </div>
          <div>
            <b>0</b>
            <span>accounts to create</span>
          </div>
        </section>

        <section id="keyboard" className={styles.section}>
          <h2 className={styles.h2}>Made for the keyboard.</h2>
          <p className={styles.sub}>Move with the arrow keys, then act on the save you are on.</p>
          <ul className={styles.keys}>
            {keys.map(([k, label]) => (
              <li key={k}>
                <kbd>{k}</kbd>
                <span>{label}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className={styles.private}>
          <span className={styles.privateIcon}>
            <Icon name="lock" size={20} />
          </span>
          <h2 className={styles.h2}>Your library is a folder.</h2>
          <p className={styles.sub}>
            Every save is a plain folder in iCloud Drive, or wherever you choose. Cyte reads text and colour on your
            Mac, and nothing is uploaded.
          </p>
        </section>

        <section id="download" className={styles.cta}>
          <Image src="/cyte-icon.png" alt="" width={88} height={88} className={styles.ctaIcon} />
          <h2 className={styles.h2}>Get Cyte for Mac.</h2>
          <div className={styles.pair}>
            <a className={styles.primary} href="/downloads/Cyte.dmg" download>
              <Icon name="download" size={16} />
              Download for Mac
            </a>
            <a className={styles.secondary} href="https://github.com/v1shalm/cyte">
              <Icon name="github" size={16} />
              GitHub
            </a>
          </div>
          <p className={styles.meta}>Free · macOS 26 or later · Apple silicon</p>
          <p className={styles.note}>
            On first launch, open System Settings → Privacy &amp; Security and choose Open Anyway.
          </p>
        </section>
      </main>

      <SiteFooter />
    </>
  );
}
