# Block Count

A 2-player competitive isometric memory game. Players view a grid of blocks, memorize the count, then race to answer first.

**Play now: [game1.gt.ms](https://game1.gt.ms)**

## How to Play

1. Enter player names and press **Start Game**
2. **Viewing Phase** -- A grid of blocks appears for 4 seconds. Count them!
3. **Answering Phase** -- The grid disappears. Use the controls to set your answer and lock in. You have 45 seconds.
4. First to lock in the correct answer wins the round. Wrong answers disable your lock-in for 1.5 seconds.
5. Play through 15 rounds. Highest score wins.

### Controls

| Action     | Player 1   | Player 2    |
|------------|------------|-------------|
| Increment  | D          | Right Arrow |
| Decrement  | A          | Left Arrow  |
| Lock In    | Space      | Enter       |

On-screen buttons are also available for touch/click.

## Difficulty Progression

The game gets harder across 15 rounds:

- **Rounds 1-3** -- 4x4 grid, 3-8 blocks, no grid movement
- **Rounds 4-5** -- 4x4 grid, 6-11 blocks, slow grid movement
- **Rounds 6-8** -- 5x5 grid, 8-16 blocks, medium grid movement
- **Rounds 9-11** -- 5x5 grid, 12-20 blocks, fast grid movement
- **Rounds 12-15** -- 5x5 grid, 15-25 blocks, very fast grid movement

The grid moves left-to-right (bouncing) during the viewing phase, making counting harder at higher levels.

## Visual Style

- Black and white aesthetic
- Cel-shaded 3D blocks with outline shaders
- X-ray outlines for blocks hidden behind others
- Curvy fonts (Pacifico for titles, Quicksand for UI)
- Progress bars instead of text timers

## Running Locally

### From the web export

```bash
python3 serve.py
# Open http://localhost:8080
```

### From Godot

1. Install [Godot 4.6](https://godotengine.org/download)
2. Open `project.godot` in the editor
3. Press F5 to run

### Building the web export

```bash
godot --headless --export-release "Web" --path .
python3 serve.py
```

## Tech Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Renderer**: gl_compatibility (optimized for web)
- **Target**: Web (HTML5), mobile landscape supported
