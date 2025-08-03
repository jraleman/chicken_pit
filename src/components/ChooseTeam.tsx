import React from 'react';

export type Team = 'left' | 'right';

interface ChooseTeamProps {
  onSelectTeam: (team: Team) => void;
}

/**
 * UI for selecting which side you’ll play on.
 */
const ChooseTeam: React.FC<ChooseTeamProps> = ({ onSelectTeam }) => (
  <div className="choose-team">
    <h2>Choose Your Team</h2>
    <button onClick={() => onSelectTeam('left')}>Left Team</button>
    <button onClick={() => onSelectTeam('right')}>Right Team</button>
  </div>
);

export default ChooseTeam;