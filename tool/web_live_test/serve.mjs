// Serves a Flutter web build the way Vercel does for this project: files
// first, then the rewrites from vercel.json, with vercel.json's headers on
// every response. Lets the live tests exercise the real hosting config
// without a deployment.
//
// Usage: node serve.mjs [webRoot] [port]

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const root = resolve(process.argv[2] ?? process.env.WEB_ROOT ?? join(here, '../../build/web'));
const port = Number(process.argv[3] ?? process.env.PORT ?? 4173);
const vercel = JSON.parse(await readFile(join(here, '../../vercel.json'), 'utf8'));

// vercel.json sources use path-to-regexp; this project only uses "/(.*)"
// style patterns, which translate directly.
const toRegExp = (source) => new RegExp(`^${source}$`);
const headerRules = (vercel.headers ?? []).map((r) => ({ re: toRegExp(r.source), headers: r.headers }));
const rewrites = (vercel.rewrites ?? []).map((r) => ({ re: toRegExp(r.source), destination: r.destination }));

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.frag': 'application/octet-stream',
  '.bin': 'application/octet-stream',
  '.txt': 'text/plain; charset=utf-8',
};

async function fileFor(pathname) {
  const path = normalize(join(root, decodeURIComponent(pathname)));
  if (!path.startsWith(root)) return null;
  try {
    const s = await stat(path);
    if (s.isFile()) return path;
    if (s.isDirectory()) return fileFor(join(pathname, 'index.html'));
  } catch {
    // fall through to rewrites
  }
  return null;
}

createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  let file = await fileFor(pathname);
  if (!file) {
    const rule = rewrites.find((r) => r.re.test(pathname));
    if (rule) file = await fileFor(rule.destination);
  }

  for (const rule of headerRules) {
    if (rule.re.test(pathname)) {
      for (const { key, value } of rule.headers) res.setHeader(key, value);
    }
  }

  if (!file) {
    res.writeHead(404).end('not found');
    return;
  }
  const body = await readFile(file);
  res.writeHead(200, {
    'Content-Type': types[extname(file)] ?? 'application/octet-stream',
    'Content-Length': body.length,
    'Cache-Control': 'public, max-age=0, must-revalidate',
  });
  res.end(req.method === 'HEAD' ? undefined : body);
}).listen(port, () => {
  console.log(`serving ${root} on http://localhost:${port}`);
});
