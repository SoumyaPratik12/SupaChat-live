'use client'

import React from 'react'

export default function Header() {
  return (
    <header className="bg-white/10 backdrop-blur-sm border-b border-white/20">
      <div className="container mx-auto px-6 py-4 flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 bg-gradient-to-br from-blue-400 to-purple-600 rounded-xl flex items-center justify-center text-white font-bold text-lg shadow-lg">
            SC
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white">SupaChat</h1>
            <p className="text-xs text-blue-200">Natural Language → SQL → Analytics</p>
          </div>
        </div>

        <div className="flex items-center space-x-4 text-sm">
          <span className="flex items-center space-x-1 text-green-300">
            <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse inline-block" />
            <span>Live</span>
          </span>
          <a href="/api/docs" target="_blank" rel="noreferrer"
            className="text-blue-200 hover:text-white transition-colors">
            API Docs
          </a>
          <a href="/api/health" target="_blank" rel="noreferrer"
            className="text-blue-200 hover:text-white transition-colors">
            Health
          </a>
        </div>
      </div>
    </header>
  )
}
