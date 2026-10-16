import { Icon } from "./icons";
import styles from "./page.module.css";

export type DemoKind = "motion" | "text" | "select" | "smart" | "similar" | "x";

export function Demo({ kind }: { kind: DemoKind }) {
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
