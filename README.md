# 🐔 Chicken Pit - Tug O' War Game

A fun and interactive Tug-O-War game built with React and Three.js!

## Features

- **3D Graphics**: Beautiful 3D rendered game using Three.js and React Three Fiber
- **Real-time Gameplay**: Interactive tug-of-war mechanics with strength meters
- **Team Competition**: Red Team vs Blue Team competition
- **Dynamic Physics**: Rope moves based on team strength difference
- **Visual Feedback**: Strength meters, position indicators, and winner announcements
- **Responsive Controls**: Click buttons to pull the rope for your team

## How to Play

1. **Red Team**: Click the "Pull!" button on the left side to add strength to the red team
2. **Blue Team**: Click the "Pull!" button on the right side to add strength to the blue team
3. **Objective**: Pull the rope to your side! Get the rope past your goal line to win
4. **Strategy**: Strength decays over time, so timing and coordination matter
5. **Reset**: Use the "Reset Game" button to start a new match

## Game Mechanics

- **Strength System**: Each button click adds 15 strength points (max 100)
- **Decay**: Strength automatically decreases by 1 point every 100ms
- **Rope Movement**: The rope moves based on the difference in team strengths
- **Win Conditions**: Move the rope 4.5 units toward your goal line to win
- **Visual Indicators**: 
  - Green field with white center line and colored goal lines
  - 3D player characters representing each team
  - Animated rope with golden center marker
  - Spectator characters cheering from the sidelines

## Technology Stack

- **React 18**: Modern React with hooks for state management
- **Three.js**: 3D graphics and physics
- **React Three Fiber**: React renderer for Three.js
- **React Three Drei**: Useful helpers and components
- **Vite**: Fast development build tool

## Getting Started

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