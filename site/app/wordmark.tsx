import styles from "./home.module.css";

const strokes: { d: string; w?: number }[] = [
  { d: "M247.8 212.2 A110 110 0 1 0 247.8 367.8" },
  { d: "M392 186 L492 398" },
  { d: "M590 186 L452 520" },
  { d: "M750 70 V320 A80 80 0 0 0 830 400" },
  { d: "M700 190 H840" },
  { d: "M940 290 H1180", w: 70 },
  { d: "M1180 290 A120 120 0 1 0 1144.9 374.9" },
];

const order = [0, 4, 2, 6, 1, 5, 3];

export function Wordmark() {
  return (
    <svg className={styles.wordmark} viewBox="-30 0 1300 600" role="img" aria-label="Cyte">
      {strokes.map((s, i) => (
        <path key={s.d} d={s.d} pathLength={1} style={{ animationDelay: `${1520 + order[i] * 70}ms`, strokeWidth: s.w }} />
      ))}
    </svg>
  );
}
