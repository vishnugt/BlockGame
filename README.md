# Block Count

A 2-player competitive isometric memory game. Players view a grid of blocks, memorize the count, then race to answer first. Supports both local (same device) and online multiplayer.

**Play now: [game1.gt.ms](https://game1.gt.ms)**

## How to Play

1. Choose **LOCAL** or **ONLINE** from the main menu
2. **Viewing Phase** — A grid of blocks appears for 4 seconds. Count them!
3. **Answering Phase** — The grid disappears. Use the controls to set your answer and lock in. You have 45 seconds.
4. First to lock in the correct answer wins the round. Wrong answers disable your lock-in for 1.5 seconds.
5. Play through 15 rounds. Highest score wins.

### Online Multiplayer

1. Both players open [game1.gt.ms](https://game1.gt.ms)
2. Player 1 clicks **ONLINE** → enter name → **CREATE ROOM** → share the link
3. Player 2 opens the shared link (room code pre-filled) → enter name → **JOIN**

### Controls (Local)

| Action     | Player 1   | Player 2    |
|------------|------------|-------------|
| Increment  | D          | Right Arrow |
| Decrement  | A          | Left Arrow  |
| Lock In    | Space      | Enter       |

On-screen buttons are also available for touch/click.

## Difficulty Progression

- **Rounds 1-3** — 4x4 grid, 3-6 blocks, no movement
- **Rounds 4-5** — 4x4 grid, 6-11 blocks, slow movement
- **Rounds 6-8** — 5x5 grid, 8-16 blocks, medium movement
- **Rounds 9-11** — 5x5 grid, 12-20 blocks, fast movement
- **Rounds 12-15** — 5x5 grid, 15-25 blocks, very fast movement

## Tech Stack

- **Engine**: Godot 4.6 / GDScript
- **Renderer**: gl_compatibility (optimized for web)
- **Multiplayer server**: Node.js + `ws`
- **Hosting**: Nginx Proxy Manager + Docker on gt.ms

---

## Development

### Run locally (web export)

```bash
python3 serve.py
# Open http://localhost:8080
```

### Run from Godot editor

1. Install [Godot 4.6](https://godotengine.org/download)
2. Open `project.godot`
3. Press F5

### Build web export

```bash
godot --headless --export-release "Web" --path .
```

Output goes to `build/web/`.

---

## Deployment

### Architecture

```
game1.gt.ms          → /root/BlockGame        (Python static server, Docker)
api-game1.gt.ms      → /root/game1-server     (Node.js WS server, Docker)
```

Both containers are on `npm_network` and proxied through Nginx Proxy Manager.

### Deploy game (frontend)

```bash
# 1. Build web export
godot --headless --export-release "Web" --path .

# 2. Sync to server
rsync -av --exclude='*.import' build/web/ root@gt.ms:/root/BlockGame/build/web/
```

### Deploy multiplayer server

```bash
# Copy server files
scp server/index.js server/room_manager.js server/game_logic.js \
    server/package.json server/docker-compose.yml \
    root@gt.ms:/root/game1-server/

# Start (first time)
ssh root@gt.ms "cd /root/game1-server && docker compose up -d"

# Restart after updates
ssh root@gt.ms "cd /root/game1-server && docker compose restart"

# Check logs
ssh root@gt.ms "cd /root/game1-server && docker compose logs -f"
```

### NPM proxy setup

Add two proxy hosts in Nginx Proxy Manager (`http://<server>:81`):

| Domain | Forward Host | Port | Websockets |
|--------|-------------|------|------------|
| `game1.gt.ms` | `blockgame` | `8080` | No |
| `api-game1.gt.ms` | `game1-server` | `3001` | **Yes** |

Enable SSL (Let's Encrypt) on both. Websocket support is required for `api-game1.gt.ms`.

### Environment

The multiplayer server is configured via `docker-compose.yml` environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3001` | Server port |
| `ALLOWED_ORIGIN` | `https://game1.gt.ms` | Comma-separated allowed origins |
