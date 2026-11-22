"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createPool = createPool;
const pg_1 = __importDefault(require("pg"));
/** Build a connection pool from DATABASE_URL (no default on purpose). */
function createPool() {
    const url = process.env.DATABASE_URL;
    if (!url) {
        throw new Error("DATABASE_URL is not set");
    }
    return new pg_1.default.Pool({
        connectionString: url,
        max: Number(process.env.DB_POOL_MAX ?? 10),
        connectionTimeoutMillis: 5000,
    });
}
