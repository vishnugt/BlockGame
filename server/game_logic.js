'use strict';

const { broadcast, sendToSlot, destroyRoom } = require('./room_manager');

// Must match LevelConfig in Godot exactly (level_config.gd)
const LEVELS = [
  // Rounds 1-2: 4x4 (16 cells, max 8), no movement
  { grid_size: 4, min_blocks: 3,  max_blocks: 6,  max_height: 1, grid_speed: 0.0, view_time: 4.0, use_dominos: false },
  { grid_size: 4, min_blocks: 4,  max_blocks: 8,  max_height: 1, grid_speed: 0.0, view_time: 4.0, use_dominos: false },
  // Rounds 3-4: 4x4, slow movement
  { grid_size: 4, min_blocks: 5,  max_blocks: 8,  max_height: 1, grid_speed: 1.0, view_time: 4.0, use_dominos: false },
  { grid_size: 4, min_blocks: 6,  max_blocks: 8,  max_height: 1, grid_speed: 1.5, view_time: 4.0, use_dominos: false },
  // Rounds 5-6: 5x5 (25 cells, max 12), medium movement
  { grid_size: 5, min_blocks: 7,  max_blocks: 12, max_height: 1, grid_speed: 2.0, view_time: 4.0, use_dominos: false },
  { grid_size: 5, min_blocks: 9,  max_blocks: 12, max_height: 1, grid_speed: 2.5, view_time: 4.0, use_dominos: false },
  // Rounds 7-8: 6x6 (36 cells), fast movement
  { grid_size: 6, min_blocks: 8,  max_blocks: 12, max_height: 1, grid_speed: 3.5, view_time: 4.0, use_dominos: false },
  { grid_size: 6, min_blocks: 10, max_blocks: 15, max_height: 1, grid_speed: 4.5, view_time: 4.0, use_dominos: false },
];

const TOTAL_ROUNDS = 8;
const ANSWER_TIME_MS = 45000;
const RESULT_DISPLAY_MS = 2500;

// PCG32 — matches Godot 4's RandomNumberGenerator exactly
// Reference: https://www.pcg-random.org/
// Godot uses: state=seed, inc=1442695040888963407 (default stream)
function Rng(seed) {
  // Use BigInt for 64-bit arithmetic
  const INC = 1442695040888963407n;
  const MUL = 6364136223846793005n;
  const MASK64 = 0xFFFFFFFFFFFFFFFFn;
  const MASK32 = 0xFFFFFFFFn;

  let state = BigInt(seed >>> 0);
  // Initialize: advance once
  state = ((state * MUL) + INC) & MASK64;

  function next() {
    const s = state;
    state = ((s * MUL) + INC) & MASK64;
    // PCG output function (xsh-rr)
    const xorshifted = Number(((s >> 18n) ^ s) >> 27n) >>> 0;
    const rot = Number(s >> 59n);
    return ((xorshifted >>> rot) | (xorshifted << ((-rot) & 31))) >>> 0;
  }

  return {
    randiRange(lo, hi) {
      const range = hi - lo + 1;
      // Unbiased bounded random (same as Godot's implementation)
      const threshold = ((2 ** 32) - range) % range;
      let r;
      do { r = next(); } while (r < threshold);
      return lo + (r % range);
    }
  };
}

// Mirrors game_grid.gd generate_layout to compute the correct answer server-side.
// All current levels have use_dominos=false and max_height=1, so the answer equals
// rng.randiRange(min_blocks, max_blocks) as long as the grid has sufficient capacity
// (which it always does for current level configs).
function computeCorrectAnswer(level, seed) {
  const rng = Rng(seed);
  const gridSize = level.grid_size;
  const numBlocks = rng.randiRange(level.min_blocks, level.max_blocks);
  const maxHeight = level.max_height;
  const useDominos = level.use_dominos;

  // For use_dominos=false and max_height=1 (all current levels), blocks_placed == numBlocks
  // provided gridSize^2 >= numBlocks. We still simulate the full loop to be safe.
  const grid = Array.from({ length: gridSize }, () => new Array(gridSize).fill(0));
  let blocksPlaced = 0;

  // No domino branch needed (use_dominos always false) but kept for correctness
  let attempts = 0;
  while (blocksPlaced < numBlocks && attempts < 200) {
    attempts++;
    const x = rng.randiRange(0, gridSize - 1);
    const z = rng.randiRange(0, gridSize - 1);
    if (grid[x][z] >= maxHeight) continue;
    grid[x][z]++;
    blocksPlaced++;
  }

  return blocksPlaced;
}

function startGame(room) {
  room.state = 'IN_GAME';
  room.p1_score = 0;
  room.p2_score = 0;
  room.current_round = null;
  const p1 = room.slots[1];
  const p2 = room.slots[2];
  console.log(`[GAME] start room=${room.id} p1=${p1.name} p2=${p2.name}`);
  broadcast(room, {
    type: 'game_start',
    p1_name: p1.name,
    p2_name: p2.name,
  });
  setTimeout(() => startRound(room), 1000);
}

function startRound(room) {
  if (!room) return;
  const roundNumber = (room.current_round ? room.current_round.number : 0) + 1;
  const levelIndex = roundNumber - 1;
  const level = LEVELS[levelIndex];
  const seed = (Math.floor(Math.random() * 0xFFFFFFFE) + 1); // never 0
  const correctAnswer = computeCorrectAnswer(level, seed);

  room.current_round = {
    number: roundNumber,
    seed,
    level_index: levelIndex,
    correct_answer: correctAnswer,
    p1_correct: false,
    p2_correct: false,
    ended: false,
    answer_timer: null,
  };

  const viewMs = Math.round(level.view_time * 1000);
  console.log(`[GAME] round=${roundNumber} room=${room.id} seed=${seed} answer=${correctAnswer}`);
  broadcast(room, {
    type: 'round_start',
    round: roundNumber,
    seed,
    level_index: levelIndex,
    view_duration_ms: viewMs,
    answer_duration_ms: ANSWER_TIME_MS,
    server_ts: Date.now(),
  });

  // After view time, start answer phase
  setTimeout(() => {
    if (!room.current_round || room.current_round.ended) return;
    broadcast(room, { type: 'answer_phase_start', server_ts: Date.now() });
    room.current_round.answer_timer = setTimeout(() => endRound(room), ANSWER_TIME_MS);
  }, viewMs);
}

function handleLockIn(room, slot, answer) {
  const round = room.current_round;
  if (!round || round.ended) return;

  const isCorrect = (answer === round.correct_answer);

  if (!isCorrect) {
    sendToSlot(room, slot, { type: 'lock_in_result', slot, correct: false, cooldown_ms: 1500 });
    // Re-enable input after cooldown
    setTimeout(() => {
      if (!round.ended) {
        sendToSlot(room, slot, { type: 'reactivate_input', slot });
      }
    }, 1500);
    return;
  }

  // Correct answer
  if (slot === 1) {
    if (round.p1_correct) return;
    round.p1_correct = true;
    room.p1_score++;
  } else {
    if (round.p2_correct) return;
    round.p2_correct = true;
    room.p2_score++;
  }

  // Determine round winner so far
  let roundWinner;
  if (round.p1_correct && round.p2_correct) {
    roundWinner = 0; // both
  } else if (round.p1_correct) {
    roundWinner = 1;
  } else {
    roundWinner = 2;
  }

  broadcast(room, {
    type: 'lock_in_result',
    slot,
    correct: true,
    p1_score: room.p1_score,
    p2_score: room.p2_score,
    round_winner: roundWinner,
  });

  // If one player got it, end the round (other player can't win anymore)
  if (round.p1_correct || round.p2_correct) {
    endRound(room);
  }
}

function endRound(room) {
  const round = room.current_round;
  if (!round || round.ended) return;
  round.ended = true;
  clearTimeout(round.answer_timer);

  let roundWinner = -1;
  if (round.p1_correct && round.p2_correct) roundWinner = 0;
  else if (round.p1_correct) roundWinner = 1;
  else if (round.p2_correct) roundWinner = 2;

  broadcast(room, {
    type: 'round_end',
    correct_answer: round.correct_answer,
    round_winner: roundWinner,
    p1_score: room.p1_score,
    p2_score: room.p2_score,
  });

  if (round.number >= TOTAL_ROUNDS) {
    setTimeout(() => endGame(room), RESULT_DISPLAY_MS);
  } else {
    setTimeout(() => startRound(room), RESULT_DISPLAY_MS);
  }
}

function endGame(room) {
  let winner = 0;
  if (room.p1_score > room.p2_score) winner = 1;
  else if (room.p2_score > room.p1_score) winner = 2;

  broadcast(room, {
    type: 'game_over',
    winner,
    p1_score: room.p1_score,
    p2_score: room.p2_score,
  });

  setTimeout(() => destroyRoom(room.id), 60000);
}

module.exports = { startGame, startRound, handleLockIn };
