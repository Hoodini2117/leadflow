import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // API_INTERNAL_URL is supplied at build time for containerized production.
  // DEV_API_URL keeps the local development proxy independent of the UI host.
  async rewrites() {
    const apiUrl =
      process.env.NODE_ENV === "production"
        ? process.env.API_INTERNAL_URL
        : process.env.DEV_API_URL ?? "http://localhost:3001";
    if (!apiUrl) return [];

    return [
      {
        source: "/api/:path*",
        destination: `${apiUrl.replace(/\/+$/, "")}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
