const http = require('http');

const PROXY_PORT = 8082;
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = 8080;

const server = http.createServer((clientReq, clientRes) => {
  // CORS headers
  clientRes.setHeader('Access-Control-Allow-Origin', '*');
  clientRes.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  clientRes.setHeader('Access-Control-Allow-Headers', '*');

  if (clientReq.method === 'OPTIONS') {
    clientRes.writeHead(204);
    clientRes.end();
    return;
  }

  const options = {
    hostname: TARGET_HOST,
    port: TARGET_PORT,
    path: clientReq.url,
    method: clientReq.method,
    headers: {
      ...clientReq.headers,
      host: `${TARGET_HOST}:${TARGET_PORT}`,
    },
  };

  const proxyReq = http.request(options, (targetRes) => {
    clientRes.writeHead(targetRes.statusCode, targetRes.headers);
    targetRes.pipe(clientRes, { end: true });
  });

  proxyReq.on('error', (err) => {
    console.error(`[Bridge Error] Failed to reach backend: ${err.message}`);
    if (!clientRes.headersSent) {
      clientRes.writeHead(502, { 'Content-Type': 'application/json' });
      clientRes.end(JSON.stringify({ error: `Bridge error: ${err.message}` }));
    }
  });

  clientReq.pipe(proxyReq, { end: true });
});

server.listen(PROXY_PORT, '0.0.0.0', () => {
  console.log(`🚀 Themis Node Bridge running on http://0.0.0.0:${PROXY_PORT} -> http://${TARGET_HOST}:${TARGET_PORT}`);
});
