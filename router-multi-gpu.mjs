// =============================================================================
// Multi-GPU Router for LOCAL STAFF
// Routes models across: local CPU (laptop), Azure V100, Kaggle T4 (ngrok), HF free GPU
// =============================================================================

import { createHash } from 'crypto';

const GPU_BACKENDS = {
  local:  'http://127.0.0.1:8090',       // llama.cpp on laptop CPU
  azure:  process.env.AZURE_GPU_URL  || 'http://YOUR-AZURE-IP:11434',
  kaggle: process.env.KAGGLE_GPU_URL || 'http://YOUR-KAGGLE-NGROK.ngrok-free.dev',
  hf:     process.env.HF_GPU_URL     || 'https://YOUR-HF-SPACE.hf.space',
};

// Model → backend mapping
const MODEL_BACKEND_MAP = {
  // Local CPU models (small, fast)
  'local-staff/smoke-0.5b':  'local',
  'local-staff/smoke-360m':  'local',
  'local-staff/coder-1.5b':  'local',
  'local-staff/coder-3b':    'local',
  'local-staff/coder-14b':   'local',

  // Azure V100 models (uncensored conversational + coder)
  'amanda-nsfw-9b':          'azure',
  'amanda-nsfw-9b-v2':       'azure',
  'brand-9b-abliterated':    'azure',
  'coder-32b':               'azure',
  'coder-14b-azure':         'azure',

  // Kaggle ngrok models (large brand + diffusion)
  'brand-35b':               'kaggle',
  'brand-27b':               'kaggle',
  'qwen3.6-35b':             'kaggle',
  'qwen3.8-27b':             'kaggle',

  // HF free GPU overflow
  'hf-overflow':             'hf',
};

function selectGPU(modelId) {
  return MODEL_BACKEND_MAP[modelId] || 'local';
}

function backendUrl(backend) {
  return GPU_BACKENDS[backend] || GPU_BACKENDS.local;
}

export { GPU_BACKENDS, MODEL_BACKEND_MAP, selectGPU, backendUrl };