import React from 'react';
import { LEFT_TEAM_LABEL, RIGHT_TEAM_LABEL } from '../contants';

export type Team = 'left' | 'right';

interface ChooseTeamProps {
  onSelectTeam: (team: Team) => void;
}

const ChooseTeam: React.FC<ChooseTeamProps> = ({ onSelectTeam }) => (
  <div className="choose-team">
    <h3>Choose Your Team</h3>
    <div className="team-buttons">
      <button onClick={() => onSelectTeam('left')}>{LEFT_TEAM_LABEL}</button>
      <button onClick={() => onSelectTeam('right')}>{RIGHT_TEAM_LABEL}</button>
    </div>
  </div>
);

export default ChooseTeam;
