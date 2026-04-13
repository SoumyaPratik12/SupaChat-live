/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  pageExtensions: ['ts', 'tsx', 'js', 'jsx'],
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || '/api',
  },
  async rewrites() {
    const backendUrl = process.env.BACKEND_URL || 'http://localhost:8000'
    return [
      { source: '/api/:path*',   destination: `${backendUrl}/:path*` },
      { source: '/docs',         destination: `${backendUrl}/docs` },
      { source: '/openapi.json', destination: `${backendUrl}/openapi.json` },
      { source: '/redoc',        destination: `${backendUrl}/redoc` },
    ]
  },
}

module.exports = nextConfig
