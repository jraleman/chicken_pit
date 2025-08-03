export const ROPE_COLOR = '#8b4513';
export const LEFT_TEAM_COLOR = '#3b5998';
export const RIGHT_TEAM_COLOR = '#ea4335';
export const ROPE_LENGTH = 4;
export const SLIDE_SHOW_DURATION = 5000; // Duration in milliseconds for the slideshow scene
export const INTRO_DURATION = 8000; // Duration in milliseconds for the intro scene
export const LEFT_TEAM_LABEL = 'B Team'; // Label for the left team
export const RIGHT_TEAM_LABEL = 'A Team'; // Label for the right team
export const GAME_TITLE = 'Chicken Pit'; // Title of the game
export const GAME_DESCRIPTION = 'A fun and competitive game where teams pull a rope to win!'; // Description of the game
export const GAME_VERSION = '1.0.0'; // Version of the game
export const GAME_AUTHOR = 'DeskCanSaw Games'; // Author of the game
export const GAME_COPYRIGHT = '© 2025 DeskCanSaw Games'; // Copyright information
export const GAME_LOGO_URL = 'https://deskcansaw.com/games/logo.png'; // URL for the game logo
export const GAME_BACKGROUND_COLOR = '#f0f0f0'; // Background color for the game
export const GAME_FOOTER_TEXT = 'Made with love by DeskCanSaw 🐢🕶️'; // Footer text for the game
export const GAME_FOOTER_LINK = 'https://deskcansaw.com'; // Link for the footer text
export const GAME_FOOTER_LINK_TEXT = 'Visit our website'; // Text for the footer link
export const LEFT_TEAM_CONTROLS = ['a', 'q']; // Controls for the left team
export const RIGHT_TEAM_CONTROLS = ['l', 'p']; // Controls for the right team
export const MULTIPLAYER_LEFT_LABEL = 'Left Team (A/Q)'; // Label for left team in multiplayer
export const MULTIPLAYER_RIGHT_LABEL = 'Right Team (L/P)'; // Label for right team in multiplayer
//   pull: 'A',
//   release: 'D',
//   jump: 'W',
//   crouch: 'S',
// }; // Controls for the left team
// export const RIGHT_TEAM_CONTROLS = {
//   pull: 'L',
//   release: ';',
//   jump: 'I',
//   crouch: 'K',
// }; // Controls for the right team
export const GAME_SETTINGS = {
  ropeLength: ROPE_LENGTH,
  ropeColor: ROPE_COLOR,
  leftTeamColor: LEFT_TEAM_COLOR,
  rightTeamColor: RIGHT_TEAM_COLOR,
  leftTeamLabel: LEFT_TEAM_LABEL,
  rightTeamLabel: RIGHT_TEAM_LABEL,
  leftTeamControls: LEFT_TEAM_CONTROLS,
  rightTeamControls: RIGHT_TEAM_CONTROLS,
}; // Default game settings for the game
export const GAME_SLIDES = [
  {
    id: 1,
    title: 'Welcome to Chicken Pit',
    subtitle: 'A fun tug-of-war game',
    backgroundColor: '#f0f0f0',
    logoUrl: GAME_LOGO_URL,
  },
  {
    id: 2,
    title: 'Choose Your Team',
    subtitle: 'Select your team and get ready to pull!',
    backgroundColor: LEFT_TEAM_COLOR,
    logoUrl: 'https://deskcansaw.com/games/left-team-logo.png',
  },
  {
    id: 3,
    title: 'Game Settings',
    subtitle: 'Adjust your game settings before starting',
    backgroundColor: RIGHT_TEAM_COLOR,
    logoUrl: 'https://deskcansaw.com/games/right-team-logo.png',
  },
    { 
        id: 4,
        title: 'Get Ready',
        subtitle: 'Prepare for an exciting game of tug-of-war!',
        backgroundColor: '#2c3e50',
        },
    {
        id: 5,
        title: 'Good Luck!',
        subtitle: 'May the best team win!',
        backgroundColor: '#8e44ad',
        },
]; // Slides for the slideshow scene

export const GAME_INTRO_TEXT = `
The humid dawn air in Athens, Georgia,
trembled as the ER Nurse stepped onto the chicken-processing farm, 
stethoscope swinging by her side. 

Called for a patient in distress, 
she leaned over the edge of the vast chicken pit—and slipped. 

Feathers and clucks swirled as she sank into the cool muck, 
hidden from sight for hours. 

When rescuers at last hauled her out, 
she was rushed back to the very ER she served.

In her fevered haze, two figures emerged: 
the Blue Chicken, calm and guiding, 
and the Red Chicken, frantic and insistent. 

Blue whispered, “Breathe, steady your heart.” 
Red crowed, “Act now, shove through!” 

Instantly, the walls of her breakdown peeled away—she was free of the pit.
`;
export const GAME_INTRO_DURATION = 45; // Duration in seconds for the intro scene
export const GAME_INITIAL_SCENE_IDX = 1;
export const GAME_AUDIO_VOLUME = 1; // Set the volume for the intro audio
