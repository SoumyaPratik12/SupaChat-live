'use client'

import React from 'react'

export default function Header() {
  return (
    <header className="bg-white shadow-sm border-b border-gray-200">
      <div className="container mx-auto px-6 py-4 flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center text-white font-bold text-lg">
            SC
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-800">SupaChat</h1>
            <p className="text-sm text-gray-600">Natural Language Analytics with Supabase</p>
          </div>
        </div>
        <div className="flex items-center space-x-4 text-sm text-gray-600">
          <span>🟢 Connected</span>
          <a href="/api/docs" className="text-blue-600 hover:underline">Docs</a>
        </div>
      </div>
    </header>
  )
}
