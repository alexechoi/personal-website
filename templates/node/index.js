import { createServer } from "node:http";

const port = process.env.PORT || 8080;

createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(`<h1>__SLUG__</h1><p>You asked for <code>${req.url}</code>.</p>`);
}).listen(port, () => console.log(`listening on http://localhost:${port}`));
