'use strict';

const ROOM_EXPIRY_MS = 5 * 60 * 1000; // 5 min waiting for 2nd player
const RECONNECT_WINDOW_MS = 30 * 1000;

const rooms = new Map();

const FRUITS = [
  'apple', 'mango', 'peach', 'grape', 'lemon', 'guava', 'melon',
  'cherry', 'banana', 'papaya', 'lychee', 'coconut', 'orange',
  'berry', 'kiwi', 'plum', 'lime', 'pear', 'fig', 'date',
];

function generateRoomId() {
  const a = FRUITS[Math.floor(Math.random() * FRUITS.length)];
  let b;
  do { b = FRUITS[Math.floor(Math.random() * FRUITS.length)]; } while (b === a);
  return `${a}-${b}`;
}

function createRoom() {
  let id;
  do { id = generateRoomId(); } while (rooms.has(id));

  const room = {
    id,
    slots: { 1: null, 2: null },        // { ws, name, disconnected }
    state: 'WAITING',                    // WAITING | READY | IN_GAME
    p1_score: 0,
    p2_score: 0,
    current_round: null,
    expiry_timer: null,
    reconnect_timers: {},
  };

  // Expire if second player never joins
  room.expiry_timer = setTimeout(() => {
    if (room.state === 'WAITING') {
      destroyRoom(id);
    }
  }, ROOM_EXPIRY_MS);

  rooms.set(id, room);
  return room;
}

function getRoom(id) {
  return rooms.get(id) || null;
}

function destroyRoom(id) {
  const room = rooms.get(id);
  if (!room) return;
  clearTimeout(room.expiry_timer);
  for (const t of Object.values(room.reconnect_timers)) clearTimeout(t);
  // Close any lingering sockets
  for (const slot of [1, 2]) {
    const p = room.slots[slot];
    if (p && p.ws && p.ws.readyState === 1 /* OPEN */) {
      p.ws.close(1000, 'Room closed');
    }
  }
  rooms.delete(id);
}

// Returns assigned slot (1 or 2) or null if room is full/invalid
function joinRoom(room, ws, playerName) {
  let slot = null;
  // Check for reconnect: name matches a disconnected slot
  for (const s of [1, 2]) {
    const p = room.slots[s];
    if (p && p.disconnected && p.name === playerName) {
      slot = s;
      clearTimeout(room.reconnect_timers[s]);
      delete room.reconnect_timers[s];
      p.ws = ws;
      p.disconnected = false;
      return { slot, rejoin: true };
    }
  }
  // Assign to first empty slot
  for (const s of [1, 2]) {
    if (!room.slots[s]) {
      slot = s;
      room.slots[s] = { ws, name: playerName, disconnected: false };
      return { slot, rejoin: false };
    }
  }
  return null; // full
}

function markDisconnected(room, slot) {
  const p = room.slots[slot];
  if (!p) return;
  p.disconnected = true;
  p.ws = null;

  if (room.state === 'IN_GAME') {
    room.reconnect_timers[slot] = setTimeout(() => {
      // Player didn't reconnect — end the game
      const other = slot === 1 ? 2 : 1;
      broadcast(room, { type: 'game_over', winner: other, p1_score: room.p1_score, p2_score: room.p2_score, reason: 'opponent_disconnected' });
      destroyRoom(room.id);
    }, RECONNECT_WINDOW_MS);
  } else {
    destroyRoom(room.id);
  }
}

function send(ws, data) {
  if (ws && ws.readyState === 1) {
    ws.send(JSON.stringify(data));
  }
}

function broadcast(room, data) {
  for (const slot of [1, 2]) {
    const p = room.slots[slot];
    if (p && !p.disconnected) send(p.ws, data);
  }
}

function sendToSlot(room, slot, data) {
  const p = room.slots[slot];
  if (p && !p.disconnected) send(p.ws, data);
}

module.exports = { createRoom, getRoom, destroyRoom, joinRoom, markDisconnected, broadcast, sendToSlot, send };
