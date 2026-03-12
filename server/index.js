'use strict';

const http = require('http');
const { WebSocketServer } = require('ws');
const { createRoom, getRoom, joinRoom, markDisconnected, broadcast, sendToSlot } = require('./room_manager');
const { startGame, handleLockIn } = require('./game_logic');

const PORT = process.env.PORT || 3001;
const ALLOWED_ORIGINS = new Set((process.env.ALLOWED_ORIGIN || 'https://game1.gt.ms').split(',').map(s => s.trim()));

function isAllowedOrigin(origin) {
  if (!origin || origin === 'null') return true; // file:// or non-browser
  return ALLOWED_ORIGINS.has(origin);
}

// --- HTTP server ---
const server = http.createServer((req, res) => {
  const reqOrigin = req.headers['origin'] || '';
  const corsOrigin = isAllowedOrigin(reqOrigin) ? reqOrigin || '*' : ALLOWED_ORIGINS.values().next().value;
  // CORS
  res.setHeader('Access-Control-Allow-Origin', corsOrigin);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost`);

  if (req.method === 'GET' && url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/room') {
    const room = createRoom();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ room_id: room.id }));
    return;
  }

  if (req.method === 'GET' && url.pathname.startsWith('/room/')) {
    const id = url.pathname.slice(6).toUpperCase();
    const room = getRoom(id);
    if (!room) {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Room not found' }));
      return;
    }
    const full = room.slots[1] && !room.slots[1].disconnected &&
                 room.slots[2] && !room.slots[2].disconnected;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ room_id: id, state: room.state, joinable: !full }));
    return;
  }

  res.writeHead(404);
  res.end();
});

// --- WebSocket server ---
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const roomId = (url.searchParams.get('room') || '').toUpperCase();
  const playerName = decodeURIComponent(url.searchParams.get('name') || 'Player').slice(0, 20);

  // Validate origin
  const origin = req.headers['origin'] || '';
  console.log(`[WS] connect room=${roomId} name=${playerName} origin=${origin}`);
  if (!isAllowedOrigin(origin)) {
    console.log(`[WS] rejected origin: ${origin}`);
    ws.close(4003, 'Forbidden');
    return;
  }

  const room = getRoom(roomId);
  if (!room) {
    console.log(`[WS] room not found: ${roomId}`);
    ws.close(4000, 'Room not found');
    return;
  }

  const result = joinRoom(room, ws, playerName);
  if (!result) {
    console.log(`[WS] room full: ${roomId}`);
    ws.close(4001, 'Room is full');
    return;
  }

  const { slot, rejoin } = result;
  console.log(`[WS] slot=${slot} rejoin=${rejoin} room=${roomId}`);

  // Tell this player their slot
  ws.send(JSON.stringify({ type: 'room_joined', your_slot: slot, room_id: roomId }));

  if (rejoin) {
    // Resend current game state so they can catch up
    if (room.current_round && !room.current_round.ended) {
      ws.send(JSON.stringify({
        type: 'rejoin_state',
        round: room.current_round.number,
        p1_score: room.p1_score,
        p2_score: room.p2_score,
      }));
    }
    // Notify other player they're back
    const other = slot === 1 ? 2 : 1;
    sendToSlot(room, other, { type: 'player_connected', slot, name: playerName });
  } else {
    // Notify the other player (if present)
    const other = slot === 1 ? 2 : 1;
    if (room.slots[other]) {
      sendToSlot(room, other, { type: 'player_connected', slot, name: playerName });
    }

    // Both players connected — start game
    if (room.slots[1] && !room.slots[1].disconnected &&
        room.slots[2] && !room.slots[2].disconnected &&
        room.state === 'WAITING') {
      room.state = 'READY';
      clearTimeout(room.expiry_timer);
      startGame(room);
    }
  }

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }

    switch (msg.type) {
      case 'lock_in':
        if (typeof msg.answer === 'number') {
          handleLockIn(room, slot, msg.answer);
        }
        break;
      case 'number_changed':
        if (typeof msg.value === 'number') {
          const other = slot === 1 ? 2 : 1;
          sendToSlot(room, other, { type: 'opponent_number_changed', slot, value: msg.value });
        }
        break;
    }
  });

  ws.on('close', () => {
    markDisconnected(room, slot);
    const other = slot === 1 ? 2 : 1;
    if (room.slots[other] && !room.slots[other].disconnected) {
      sendToSlot(room, other, { type: 'player_disconnected', slot });
    }
  });

  ws.on('error', (err) => {
    console.error(`WS error slot ${slot} room ${roomId}:`, err.message);
  });
});

server.listen(PORT, () => {
  console.log(`Block Count server running on port ${PORT}`);
  console.log(`Allowed origins: ${[...ALLOWED_ORIGINS].join(', ')}`);
});
