import './globals.css'
import React from 'react'

export const metadata = {
  title: 'SupaChat - Analytics Dashboard',
  description: 'Natural language analytics with Supabase',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  )
}
