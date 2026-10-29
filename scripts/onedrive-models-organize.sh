#!/bin/bash
# =============================================================================
# OneDrive 2TB Model Storage + Neocortex Memory Organizer
# Organizes HF models + Beryl Neocortex memory on OneDrive
# OneDrive path: /mnt/c/Users/chant/OneDrive/
# =============================================================================
set -euo pipefail

ONEDRIVE="/mnt/c/Users/chant/OneDrive"
MODELS_DIR="$ONEDRIVE/MahoganyHall/Models"
BERYL_DIR="$ONEDRIVE/MahoganyHall/Beryl Engine"
NEOCORTEX_DIR="$BERYL_DIR/Neocortex Memory"
EXPERIENCE_LEDGER="$BERYL_DIR/05-Analytics-Pipeline/experience-ledger"
LOCAL_MODELS="/home/trell/.local/share/local-staff/models"

echo "=== OneDrive Model Storage Organizer ==="
echo "OneDrive: $ONEDRIVE"

# 1. Create directory structure
mkdir -p "$MODELS_DIR"/{gguf,checkpoints,lora,voice,video,diffusion}
mkdir -p "$BERYL_DIR"/{01-Portrait-Creator,02-Voice-Suite,03-Beryl-Neurons,04-Beryl-Nexus,05-Analytics-Pipeline}
mkdir -p "$NEOCORTEX_DIR"/{likes-tree,dislikes-tree,expression-trunk,episodes,assessments,strategies,lifecycles}
mkdir -p "$EXPERIENCE_LEDGER"

echo "=== Directory structure created ==="

# 2. Sync local HF models to OneDrive
if [ -d "$LOCAL_MODELS" ]; then
  echo "=== Syncing local GGUF models to OneDrive ==="
  cp -v "$LOCAL_MODELS"/*.gguf "$MODELS_DIR/gguf/" 2>/dev/null || true
fi

# 3. Copy Kokoro ONNX + voices to OneDrive
KOKORO_DIR="/home/trell/.local/share/mahogany-hall/kokoro"
if [ -d "$KOKORO_DIR" ]; then
  echo "=== Syncing Kokoro TTS to OneDrive ==="
  cp -v "$KOKORO_DIR"/* "$MODELS_DIR/voice/" 2>/dev/null || true
fi

# 4. Copy Piper voices to OneDrive
PIPER_DIR="/home/trell/.local/share/mahogany-hall/voices"
if [ -d "$PIPER_DIR" ]; then
  echo "=== Syncing Piper voices to OneDrive ==="
  cp -v "$PIPER_DIR"/* "$MODELS_DIR/voice/" 2>/dev/null || true
fi

# 5. Initialize neocortex memory databases
DB="/mnt/c/Users/chant/OneDrive/MahoganyHall/Hall/data/mahogany.db"
if [ -f "$DB" ]; then
  echo "=== Initializing neocortex tables in mahogany.db ==="
  python3 - <<'PY'
import sqlite3
db = '/mnt/c/Users/chant/OneDrive/MahoganyHall/Hall/data/mahogany.db'
c = sqlite3.connect(db)
c.executescript("""
CREATE TABLE IF NOT EXISTS neocortex_likes (
  id TEXT PRIMARY KEY, staff_id TEXT, node TEXT, parent_id TEXT,
  weight REAL DEFAULT 0.5, salience REAL DEFAULT 0.5, created_at REAL,
  onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_dislikes (
  id TEXT PRIMARY KEY, staff_id TEXT, node TEXT, parent_id TEXT,
  weight REAL DEFAULT 0.5, salience REAL DEFAULT 0.5, created_at REAL,
  onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_expression (
  id TEXT PRIMARY KEY, staff_id TEXT, channel TEXT DEFAULT 'vocal',
  node TEXT, weight REAL DEFAULT 0.5, created_at REAL,
  onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_episodes (
  id TEXT PRIMARY KEY, staff_id TEXT, summary TEXT, valence REAL,
  tags TEXT, source TEXT, created_at REAL, onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_assessments (
  id TEXT PRIMARY KEY, member_id TEXT, staff_id TEXT, traits TEXT,
  score REAL, created_at REAL, onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_strategies (
  id TEXT PRIMARY KEY, staff_id TEXT, member_id TEXT, hook TEXT,
  channel TEXT, plan TEXT, score REAL, status TEXT DEFAULT 'active',
  next_action_at REAL, created_at REAL, onedrive_path TEXT
);
CREATE TABLE IF NOT EXISTS neocortex_lifecycles (
  id TEXT PRIMARY KEY, staff_id TEXT, chapter TEXT, day INTEGER,
  entry TEXT, mood TEXT, valence REAL, created_at REAL, onedrive_path TEXT
);
""")
c.commit()
c.close()
print("Neocortex tables initialized in mahogany.db")
PY
fi

echo "=== OneDrive organization complete ==="
echo "Models: $MODELS_DIR"
echo "Neocortex Memory: $NEOCORTEX_DIR"
echo "Experience Ledger: $EXPERIENCE_LEDGER"