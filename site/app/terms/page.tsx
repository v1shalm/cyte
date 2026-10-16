import type { Metadata } from "next";
import { DocPage, issues } from "../doc";

export const metadata: Metadata = {
  title: "Terms · Cyte",
  description: "The terms for using Cyte for Mac.",
};

export default function Terms() {
  return (
    <DocPage
      title="Terms"
      updated="16 October 2026"
      lede="These terms cover your use of Cyte for Mac and this website. By installing Cyte you agree to them."
    >
      <h2>Using Cyte</h2>
      <p>
        You can install Cyte on Macs you own or control and use it for personal or work projects. Do not resell Cyte,
        remove its notices, or present it as your own product.
      </p>

      <h2>Your content</h2>
      <p>
        Everything you save stays yours. Cyte stores it as files in the folder you choose and claims no rights to it.
      </p>
      <p>
        You are responsible for what you save. Images, videos and posts from other people and sites belong to them. Cyte
        is a personal reference library, so keep what you collect for your own reference unless you have the right to
        share it.
      </p>

      <h2>Other services</h2>
      <p>
        When you import from X or keep your library in iCloud Drive or Google Drive, you use those services under their
        own terms. Cyte works with the accounts you already have there, and those services can change in ways that stop
        an import from working.
      </p>

      <h2>Updates</h2>
      <p>
        Cyte can check this website for new versions and asks before it installs one. Updates may add, change or remove
        features.
      </p>

      <h2>No warranty</h2>
      <p>
        Cyte is provided as it is, without warranties of any kind. Keep a backup of anything you cannot afford to lose.
        To the extent the law allows, the makers of Cyte are not liable for lost data, lost profits or indirect damages
        that come from using it.
      </p>

      <h2>Changes to these terms</h2>
      <p>
        If these terms change, this page shows the new date at the top. Using Cyte after a change means you accept the
        new terms.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about these terms go to <a href={issues}>GitHub issues</a>.
      </p>
    </DocPage>
  );
}
