# 🐔 Chicken Pit - Tug O' War Game 🎵

A fun and interactive Tug-O-War game built with React and Three.js with amazing audio effects!

## 🎮 Features

- **🏠 Main Menu**: Beautiful 3D main menu with running chickens in the background
- **🎯 Game Modes**: Choose between Single Player (vs AI) and Multiplayer modes
- **🐔 Team Selection**: Pick your favorite chicken team (Red or Blue) in single player
- **3D Graphics**: Beautiful 3D rendered game using Three.js and React Three Fiber
- **Real-time Gameplay**: Interactive tug-of-war mechanics with strength meters
- **Team Competition**: Red Team vs Blue Team competition
- **🤖 AI Opponents**: Smart AI chickens that adapt their strategy in single player mode
- **Dynamic Physics**: Rope moves based on team strength difference
- **Visual Feedback**: Strength meters, position indicators, and winner announcements
- **Responsive Controls**: Click buttons or use keyboard controls to pull the rope
- **🎵 AMAZING AUDIO SYSTEM**: Immersive sound experience with:
  - **Background Music**: Upbeat chicken-themed melodies during gameplay
  - **Sound Effects**: Chicken clucks, wing flaps, rope creaking, and pulling sounds
  - **Dynamic Audio**: Sounds react to game intensity and player actions
  - **Victory Fanfares**: Epic victory music with team-specific melodies
  - **Dramatic Effects**: Tension risers, heartbeat sounds during close calls
  - **Ambient Sounds**: Random chicken clucks and environmental audio
  - **Audio Controls**: Volume slider and mute button for perfect audio control
  - **Audio-Reactive Visuals**: Chickens pulse and bounce with sound effects

## 🎵 Audio Features

### 🎼 Dynamic Background Music
- Procedurally generated chicken-themed melodies
- Music adapts to game state and intensity
- Automatic looping with smooth transitions

### 🐔 Chicken Sound Effects
- Multiple chicken cluck variations
- Wing flapping sounds during intense moments
- Audio-reactive chicken animations (chickens pulse and bounce when making sounds)

### 🎯 Gameplay Audio
- Unique pull sounds for each team (different frequencies)
- Rope creaking sounds based on tension
- Strength-based audio intensity
- Sound particles and visual effects

### 🏆 Victory & Drama
- Team-specific victory fanfares (different melodies for Red vs Blue)
- Dramatic tension risers during close calls
- Heartbeat sounds when near victory
- Defeat sounds for losing team
- Celebration sparkle effects

### 🎛️ Audio Controls
- Master volume control (0-100%)
- Mute/unmute toggle
- Persistent audio settings
- Visual audio control panel

## How to Play

### 🏠 Main Menu
1. **Launch the game** to see the animated main menu with running chickens
2. **Choose Game Mode**:
   - **Single Player**: Play against smart AI chickens
   - **Multiplayer**: Play with friends locally
3. **Select Your Team** (Single Player only): Pick Red or Blue chickens
4. **Start Playing**: Jump into the tug-of-war action!

### 🎮 In-Game Controls
1. **Red Team**: Click the "Pull!" button on the left or use keyboard keys (Q, W, E)
2. **Blue Team**: Click the "Pull!" button on the right or use keyboard keys (I, O, P)
3. **Objective**: Pull the rope to your side! Get the rope past your goal line to win
4. **Strategy**: Strength decays over time, so timing and coordination matter
5. **Reset**: Use the "Reset Game" button to start a new match
6. **Main Menu**: Return to the main menu anytime with the "Main Menu" button
7. **Audio**: Use the volume control in the top-right to adjust sound levels

### 🤖 Single Player Mode
- **AI Behavior**: AI chickens adapt their pulling strategy based on the game state
- **Difficulty**: AI becomes more aggressive when losing and more defensive when winning
- **Team Control**: You can only control your selected team; the AI handles the other team

## 🎮 Game Mechanics

- **Strength System**: Each action adds 0.25 strength points (max 100)
- **Decay**: Strength automatically decreases by 1 point every 100ms
- **Rope Movement**: The rope moves based on the difference in team strengths
- **Win Conditions**: Move the rope 10.5 units toward your goal line to win
- **Audio Feedback**: Every action triggers unique sound effects
- **Visual Effects**: 
  - Green field with white center line and colored goal lines
  - 3D chicken characters representing each team with animations
  - Animated rope with dynamic positioning
  - Spectator chickens cheering from the sidelines
  - Sound particles and audio-reactive visual effects

## 🎵 Audio System Architecture

The game features a sophisticated Web Audio API-based sound system:

### Components:
- **AudioManager**: Main audio controller with background music and core sounds
- **DramaticSoundEffects**: Tension, victory, and dramatic moment sounds
- **ChickenAmbientSounds**: Random ambient chicken sounds
- **SoundParticles**: Visual particle effects that react to audio
- **AudioReactiveChicken**: Chickens that pulse and bounce with sounds

### Technical Features:
- **Procedural Audio**: All sounds generated using Web Audio API oscillators
- **Dynamic Frequency**: Different teams have unique frequency signatures
- **Audio Context Management**: Proper audio context handling and cleanup
- **Performance Optimized**: Throttled sound triggers to prevent audio spam

## 🛠️ Technology Stack

- **React 18**: Modern React with hooks for state management
- **Three.js**: 3D graphics and physics
- **React Three Fiber**: React renderer for Three.js
- **React Three Drei**: Useful helpers and components
- **Web Audio API**: Advanced procedural audio generation
- **Vite**: Fast development build tool

## 🚀 Getting Started

1. **Install Dependencies**:
   ```bash
   npm install
   ```

2. **Start Development Server**:
   ```bash
   npm run dev
   ```

3. **Open in Browser**:
   Navigate to `http://localhost:3000`

4. **Build for Production**:
   ```bash
   npm run build
   ```

## Controls

- **Mouse**: Orbit around the 3D scene (drag to rotate, scroll to zoom)
- **Red Team Button**: Add strength to red team
- **Blue Team Button**: Add strength to blue team
- **Reset Button**: Start a new game

## Game Elements

### 3D Scene
- **Players**: Colorful 3D characters representing team members
- **Rope**: Dynamic rope that moves based on game state
- **Field**: Green playing field with goal lines
- **Spectators**: Cheerful onlookers on the sidelines

### UI Elements
- **Strength Meters**: Visual bars showing each team's current pulling power
- **Position Indicator**: Shows current rope position and advantage
- **Team Controls**: Interactive buttons for each team
- **Winner Announcement**: Celebration screen when a team wins

Enjoy the game and may the best team win! 🎉