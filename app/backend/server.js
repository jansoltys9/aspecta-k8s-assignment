const http = require("node:http");
const os = require("node:os");

const PORT = Number(process.env.PORT || 3000);
const MESSAGE = process.env.APP_MESSAGE || "Hello from Aspecta Kubernetes!";
const ENVIRONMENT = process.env.APP_ENV || "local";

let apiRequests = 0;

const server = http.createServer((req, res) => {
  const path = new URL(req.url, "http://localhost").pathname;

  if (req.method !== "GET") {
    res.writeHead(405, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ error: "Method not allowed" }));
  }

  if (path === "/healthz" || path === "/readyz") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ status: "ok" }));
  }

  if (path === "/api/hello") {
    apiRequests++;

    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({
      message: MESSAGE,
      environment: ENVIRONMENT,
      hostname: os.hostname(),
      timestamp: new Date().toISOString()
    }));
  }

  if (path === "/metrics") {
    res.writeHead(200, {
      "Content-Type": "text/plain; version=0.0.4; charset=utf-8"
    });

    return res.end([
      "# HELP aspecta_api_requests_total Total API requests",
      "# TYPE aspecta_api_requests_total counter",
      `aspecta_api_requests_total ${apiRequests}`,
      "# HELP aspecta_uptime_seconds Process uptime in seconds",
      "# TYPE aspecta_uptime_seconds gauge",
      `aspecta_uptime_seconds ${process.uptime()}`,
      ""
    ].join("\n"));
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Aspecta backend listening on port ${PORT}`);
});

process.on("SIGTERM", () => {
  server.close(() => process.exit(0));
});
