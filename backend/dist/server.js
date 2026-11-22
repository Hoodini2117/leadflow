"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const app_js_1 = require("./app.js");
const db_js_1 = require("./db.js");
const port = Number(process.env.PORT ?? 3000);
const pool = (0, db_js_1.createPool)();
const server = (0, app_js_1.createApp)(pool).listen(port, "0.0.0.0", () => {
    console.log(JSON.stringify({ level: "info", msg: "listening", port, version: process.env.APP_VERSION ?? "dev" }));
});
// Finish in-flight requests, then exit.
function shutdown(signal) {
    console.log(JSON.stringify({ level: "info", msg: "shutting down", signal }));
    server.close(async () => {
        await pool.end();
        process.exit(0);
    });
    setTimeout(() => process.exit(1), 25_000).unref();
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
