import express from 'express'

import { pingLlama } from '../services/llama.ts'

const router = express.Router()

router.get('/', async (_request, response) => {
  let llamaOnline = false

  try {
    llamaOnline = await pingLlama()
  } catch (error) {
    console.warn('Failed to ping llama health endpoint:', error)
  }

  response.json({
    status: 'ok',
    uptime: process.uptime(),
    llamaOnline,
  })
})

export default router
