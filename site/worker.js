const STYLE = `
  :root { color-scheme: light dark; }
  body { margin: 0; font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  main { max-width: 40rem; margin: 0 auto; padding: 3rem 1.25rem 4rem; }
  h1 { font-size: 1.75rem; letter-spacing: -0.03em; }
  h2 { font-size: 1.1rem; margin-top: 2rem; }
  p, li { color: color-mix(in srgb, CanvasText 78%, Canvas); }
  code { font-size: 0.92em; }
  a { color: inherit; }
  nav { margin-top: 2.5rem; }
`;

function page(title, body) {
  return `<!doctype html>
<html lang="zh-Hans">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>${STYLE}</style>
<main>${body}</main>
</html>`;
}

const SUPPORT = page(
  "AI Skills Hub — Support",
  `
  <h1>AI Skills Hub</h1>
  <p>macOS 上的本地工具，用来查看、编辑、去重和归档 Cursor、Claude Code、Codex、Agents、Proma 等工具目录里的 skills 和 prompts。</p>
  <p>A local Mac app that scans, clusters, edits, deduplicates and archives skills and prompts from AI coding tools.</p>

  <h2>系统要求 / Requirements</h2>
  <p>macOS 15 或更高。完全在本机运行，无账号、无网络。</p>
  <p>macOS 15 or later. Runs entirely on your Mac; no account, no network access.</p>

  <h2>为什么要授权主目录？ / Why the home folder?</h2>
  <p>这些工具把 skills 固定放在 <code>~/.cursor/skills</code>、<code>~/.claude/skills</code>、<code>~/.codex/skills</code>、<code>~/.agents/skills</code>。应用启用了沙盒，必须由你授权一次才能读取。可随时在「文件 › 重新授权主目录」撤销或重授。</p>

  <h2>它会写哪里？ / Where does it write?</h2>
  <p>只写上述工具目录和 <code>~/.skill-hub</code>（prompt 库与归档）。收藏、标签和备注存在应用自己的容器里。不会改 Cursor 自带的 skills。</p>

  <h2>误删了怎么办 / Accidental delete</h2>
  <p>优先用「归档」而不是「删除」。归档会移到 <code>~/.skill-hub/archive</code>，把文件夹移回即可恢复。删除不可恢复，且每次都会确认。</p>

  <h2>联系 / Contact</h2>
  <p><a href="mailto:rowoverz@gmail.com">rowoverz@gmail.com</a></p>
  <nav><a href="/privacy">隐私政策 / Privacy Policy</a></nav>
  `,
);

const PRIVACY = page(
  "AI Skills Hub — Privacy Policy",
  `
  <h1>隐私政策 / Privacy Policy</h1>
  <p>Last updated: 6 September 2026</p>

  <h2>摘要 / Summary</h2>
  <p>AI Skills Hub 不收集、不传输、不分享任何个人数据。应用没有网络能力，没有分析、崩溃上报、账号或广告。</p>
  <p>AI Skills Hub does not collect, transmit, or share any personal data. The app has no network capability, no analytics, no crash reporting, no accounts and no advertising.</p>

  <h2>读取的数据 / Data the app reads</h2>
  <p>在你一次性授权后，应用会读取主目录里的 skill / prompt 文件夹（例如 <code>~/.cursor/skills</code>）以便展示和管理。这些数据不会离开这台 Mac。</p>

  <h2>保存在本机的数据 / Data stored on this Mac</h2>
  <p>你添加的收藏、标签、备注和打开次数存在应用的沙盒容器里。授权以 security-scoped bookmark 的形式保存在本机。删除应用后两者一并消失。</p>

  <h2>第三方 / Third parties</h2>
  <p>无。不含第三方 SDK，也不连接任何服务器。</p>

  <h2>变更 / Changes</h2>
  <p>若本政策更新，会发布在本页并更新日期。</p>

  <h2>联系 / Contact</h2>
  <p><a href="mailto:rowoverz@gmail.com">rowoverz@gmail.com</a></p>
  <nav><a href="/">支持 / Support</a></nav>
  `,
);

export default {
  async fetch(request) {
    const path = new URL(request.url).pathname.replace(/\/+$/, "") || "/";
    if (path === "/privacy") {
      return new Response(PRIVACY, { headers: { "content-type": "text/html; charset=utf-8" } });
    }
    if (path === "/") {
      return new Response(SUPPORT, { headers: { "content-type": "text/html; charset=utf-8" } });
    }
    return new Response("Not found", { status: 404 });
  },
};
