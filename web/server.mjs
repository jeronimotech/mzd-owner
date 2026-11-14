// MZD Owner website: static files with clean URLs and security headers. No dependencies.
// Railway sets PORT. Run locally with `node web/server.mjs` → http://localhost:8080
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), 'public');
const PORT = Number(process.env.PORT || 8080);

const ROUTES = {
  '/': 'index.html',
  '/privacidad': 'privacy.html',
  '/privacy': 'privacy.html',
  '/terminos': 'terms.html',
  '/terms': 'terms.html',
};
// Old GitHub Pages paths and store-friendly aliases
const REDIRECTS = { '/privacy.html': '/privacidad', '/terms.html': '/terminos', '/soporte': '/#preguntas', '/support': '/#preguntas' };

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8', '.json': 'application/json',
};

const SECURITY = {
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Frame-Options': 'DENY',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Strict-Transport-Security': 'max-age=31536000',
  'Content-Security-Policy':
    "default-src 'self'; img-src 'self' data:; style-src 'self' https://fonts.googleapis.com; " +
    "font-src https://fonts.gstatic.com; script-src 'none'; frame-ancestors 'none'; base-uri 'self'",
};

function send(res, status, file) {
  const ext = path.extname(file);
  const html = ext === '.html';
  res.writeHead(status, {
    ...SECURITY,
    'Content-Type': TYPES[ext] || 'application/octet-stream',
    // CSS is versioned in the HTML (styles.css?v=N); images change rarely.
    'Cache-Control': html ? 'no-cache' : 'public, max-age=86400',
  });
  fs.createReadStream(file).pipe(res);
}

http.createServer((req, res) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  } catch {
    res.writeHead(400); return res.end();
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405, { Allow: 'GET, HEAD' }); return res.end(); }
  if (pathname === '/healthz') { res.writeHead(200, { 'Content-Type': 'text/plain' }); return res.end('ok'); }

  const trimmed = pathname.length > 1 ? pathname.replace(/\/+$/, '') : pathname;
  if (REDIRECTS[trimmed]) { res.writeHead(301, { Location: REDIRECTS[trimmed] }); return res.end(); }

  const rel = ROUTES[trimmed] || trimmed.slice(1);
  const file = path.resolve(ROOT, rel);
  if (!file.startsWith(ROOT + path.sep)) { res.writeHead(403); return res.end(); }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) return send(res, 404, path.join(ROOT, '404.html'));
    send(res, 200, file);
  });
}).listen(PORT, () => console.log(`MZD Owner web on :${PORT}`));
