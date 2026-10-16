import Image from "next/image";
import { AppWindow } from "./appwindow";
import { Demo, type DemoKind } from "./demos";
import { SiteFooter, repo } from "./doc";
import { Icon, type IconName } from "./icons";
import { Wordmark } from "./wordmark";
import styles from "./home.module.css";

const download = "/downloads/Cyte.dmg";

const flyers: { x: string; y: string; r: string; w: number; h: number; kind: "art" | "type" | "chip" | "note" | "link"; tone?: string; label?: string }[] = [
  { x: "-40vw", y: "-16vh", r: "-9deg", w: 168, h: 210, kind: "art", tone: "sunset" },
  { x: "-34vw", y: "22vh", r: "7deg", w: 196, h: 124, kind: "link", tone: "mint", label: "Type specimen" },
  { x: "-24vw", y: "-34vh", r: "5deg", w: 124, h: 124, kind: "type" },
  { x: "40vw", y: "-20vh", r: "8deg", w: 170, h: 214, kind: "art", tone: "violet" },
  { x: "34vw", y: "20vh", r: "-6deg", w: 156, h: 156, kind: "note", label: "Find the poster that says kerning" },
  { x: "22vw", y: "-36vh", r: "-4deg", w: 140, h: 46, kind: "chip", label: "#poster" },
  { x: "-43vw", y: "4vh", r: "-3deg", w: 136, h: 46, kind: "chip", label: "from:x.com" },
  { x: "44vw", y: "2vh", r: "4deg", w: 116, h: 154, kind: "art", tone: "ocean" },
];

const ways: { title: string; lead: string; body: string; tone: string; demo: DemoKind }[] = [
  {
    title: "Save in one move",
    lead: "Drop it, paste it, or press ⌥⌘P.",
    body: "Images, videos, GIFs, links and notes land in one grid. Links bring their own preview, and screenshots arrive by themselves.",
    tone: "sun",
    demo: "motion",
  },
  {
    title: "Find it by what is in it",
    lead: "Search the words printed inside your images.",
    body: "Cyte reads every image on your Mac. Type kerning and the poster that says it comes up, with no tags needed.",
    tone: "sky",
    demo: "text",
  },
];

const chapters: { n: string; title: string; sub: string; cards: { icon: IconName; title: string; body: string; tone: string; art: DemoKind | "drop" | "keys" | "folder" | "colors"; keys?: string[] }[] }[] = [
  {
    n: "#1",
    title: "Saving",
    sub: "Everything you collect goes into the same grid, however it reaches you.",
    cards: [
      { icon: "plus", title: "Drop or paste anything", body: "Drag files onto the window or paste with ⌘V. Cyte keeps the original and builds the preview.", tone: "blue", art: "drop" },
      { icon: "play", title: "Videos and GIFs play", body: "They loop in the grid as you scroll. Open one to hear it, scrub it or pause it.", tone: "ink", art: "motion" },
      { icon: "bookmark", title: "X bookmarks, kept apart", body: "Import bookmarked posts with images or videos. They get their own place and stay out of Everything.", tone: "paper", art: "x" },
      { icon: "flash", title: "Save from the browser", body: "Press ⌥⌘P in any browser and the page you are reading is saved with its preview.", tone: "sun", art: "keys", keys: ["⌥", "⌘", "P"] },
    ],
  },
  {
    n: "#2",
    title: "Finding",
    sub: "Search the way you remember things: by a word, a colour or a picture that looks like it.",
    cards: [
      { icon: "scan", title: "Words inside images", body: "Cyte reads the text on posters, screenshots and slides, on your Mac.", tone: "blue", art: "text" },
      { icon: "filter", title: "Colour, site and date", body: "Filter the grid by a colour, a site or a date range without leaving it.", tone: "paper", art: "colors" },
      { icon: "similar", title: "Find similar", body: "Right-click an image to see the saves that look like it, matched on your device.", tone: "sky", art: "similar" },
      { icon: "search", title: "Search from anywhere", body: "Press ⌃⌥Space in any app to search your library without switching windows.", tone: "ink", art: "keys", keys: ["⌃", "⌥", "Space"] },
    ],
  },
  {
    n: "#3",
    title: "Keeping",
    sub: "Your library stays yours: a folder of plain files that Cyte organises on your Mac.",
    cards: [
      { icon: "sparkles", title: "Smart folders", body: "Save any filter as a folder that fills itself when new saves match.", tone: "paper", art: "smart" },
      { icon: "tick", title: "Select many, act once", body: "Shift-click a range, then tag, file or delete it together, with an undo.", tone: "sky", art: "select" },
      { icon: "folder", title: "A folder you own", body: "Every save is a plain folder in iCloud Drive or wherever you choose. Nothing is uploaded.", tone: "ink", art: "folder" },
      { icon: "keyboard", title: "Made for the keyboard", body: "Move with the arrow keys, press T to tag, F to file and Space to open.", tone: "sun", art: "keys", keys: ["T", "F", "Space"] },
    ],
  },
];

function Flyer({ f }: { f: (typeof flyers)[number] }) {
  return (
    <div
      className={styles.flyer}
      data-kind={f.kind}
      data-tone={f.tone}
      style={{ width: f.w, height: f.h, ["--x" as string]: f.x, ["--y" as string]: f.y, ["--r" as string]: f.r }}
    >
      {f.kind === "type" && <span>Aa</span>}
      {f.kind === "chip" && <span>{f.label}</span>}
      {f.kind === "note" && <p>{f.label}</p>}
      {f.kind === "link" && (
        <>
          <i />
          <b>{f.label}</b>
          <em>foundry.example</em>
        </>
      )}
    </div>
  );
}

function CardArt({ art, keys = [] }: { art: (typeof chapters)[number]["cards"][number]["art"]; keys?: string[] }) {
  switch (art) {
    case "drop":
      return (
        <div className={styles.dropArt}>
          <span>
            <Icon name="download" size={22} />
          </span>
          <p>Drop to save</p>
        </div>
      );
    case "keys":
      return (
        <div className={styles.keysArt}>
          {keys.map((k) => (
            <kbd key={k} data-wide={k.length > 1 || undefined}>
              {k}
            </kbd>
          ))}
        </div>
      );
    case "folder":
      return (
        <div className={styles.folderArt}>
          <p>iCloud Drive / Cyte</p>
          <ul>
            <li>Saves</li>
            <li>Folders</li>
            <li>Inbox</li>
          </ul>
        </div>
      );
    case "colors":
      return (
        <div className={styles.colorArt}>
          {["#111319", "#8b5a3c", "#d7263d", "#f46a1f", "#f2c230", "#3a9d5d", "#2563eb", "#7c3aed", "#ec6fa9"].map((c) => (
            <i key={c} style={{ background: c }} />
          ))}
        </div>
      );
    default:
      return <Demo kind={art} />;
  }
}

export default function Home() {
  return (
    <div className={styles.home}>
      <div className={styles.intro} aria-hidden>
        <div className={styles.introPill}>
          <i data-tone="sunset" />
          <i data-tone="violet" />
          <i data-tone="mint" />
          <i data-tone="ocean" />
          <i data-tone="sun" />
          <i data-tone="ink" />
        </div>
      </div>

      <header className={styles.minibar}>
        <a href="#top">Cyte</a>
        <span>
          <a className={styles.ghost} href={repo}>
            GitHub
          </a>
          <a className={styles.solid} href={download} download>
            Download
          </a>
        </span>
      </header>

      <section id="top" className={styles.hero}>
        <div className={styles.stage}>
          <div className={styles.blue} />
          <nav className={styles.nav}>
            <a className={styles.brand} href="#top" aria-label="Cyte">
              <Image src="/cyte-icon.png" alt="" width={26} height={26} priority />
            </a>
            <span className={styles.navLinks}>
              <a href="#how">How it works</a>
              <a href="#saving">Saving</a>
              <a href="#finding">Finding</a>
              <a href="#keeping">Keeping</a>
            </span>
            <span className={styles.navLinks}>
              <a href="/support">Support</a>
              <a href={repo}>GitHub</a>
            </span>
          </nav>
          <h1 className={styles.mark}>
            <Wordmark />
          </h1>
          <div className={styles.flyers} aria-hidden>
            {flyers.map((f) => (
              <Flyer key={f.x + f.y} f={f} />
            ))}
          </div>
          <div className={styles.rise}>
            <div className={styles.product}>
              <AppWindow />
            </div>
          </div>
        </div>
      </section>

      <div className={styles.dock}>
        <p>Save anything. Find it by the words inside.</p>
        <a className={styles.dockPrimary} href={download} download>
          <Icon name="download" size={14} />
          Download for Mac
        </a>
        <a className={styles.dockSecondary} href={repo}>
          GitHub
        </a>
      </div>

      <main className={styles.main}>
        <section id="how" className={styles.how}>
          <p className={styles.eyebrow}>
            <i /> How Cyte works
          </p>
          <div className={styles.ways}>
            {ways.map((w) => (
              <article key={w.title} className={styles.way}>
                <h2>{w.title}</h2>
                <div className={styles.wayArt} data-tone={w.tone}>
                  <Demo kind={w.demo} />
                </div>
                <p>
                  <b>{w.lead}</b> {w.body}
                </p>
              </article>
            ))}
          </div>
        </section>

        {chapters.map((c) => (
          <section key={c.n} id={c.title.toLowerCase()} className={styles.chapter}>
            <div className={styles.chapterHead}>
              <span>{c.n}</span>
              <h2>{c.title}</h2>
              <p>{c.sub}</p>
            </div>
            <div className={styles.cards}>
              {c.cards.map((card) => (
                <article key={card.title} className={styles.card}>
                  <div className={styles.cardArt} data-tone={card.tone}>
                    <CardArt art={card.art} keys={card.keys} />
                  </div>
                  <h3>
                    <Icon name={card.icon} size={15} />
                    {card.title}
                  </h3>
                  <p>{card.body}</p>
                </article>
              ))}
            </div>
          </section>
        ))}

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
            <span>accounts to create</span>
          </div>
          <div>
            <b>0</b>
            <span>servers that see your library</span>
          </div>
        </section>

        <section id="download" className={styles.final}>
          <h2>Get Cyte for Mac.</h2>
          <p>Free. macOS 26 or later on Apple silicon.</p>
          <div className={styles.finalPair}>
            <a className={styles.solidLight} href={download} download>
              <Icon name="download" size={16} />
              Download for Mac
            </a>
            <a className={styles.ghostLight} href={repo}>
              <Icon name="github" size={16} />
              GitHub
            </a>
          </div>
          <p className={styles.finalNote}>On first launch, open System Settings → Privacy &amp; Security and choose Open Anyway.</p>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
