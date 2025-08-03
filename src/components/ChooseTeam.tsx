import React from 'react';
import { LEFT_TEAM_LABEL, RIGHT_TEAM_LABEL } from '../contants';

export type Team = 'left' | 'right';

interface ChooseTeamProps {
  onSelectTeam: (team: Team) => void;
}

const ChooseTeam: React.FC<ChooseTeamProps> = ({ onSelectTeam }) => (
  <div className="choose-team">
    <h2>Choose Your Team</h2>
    <button onClick={() => onSelectTeam('left')}>{LEFT_TEAM_LABEL}</button>
    <button onClick={() => onSelectTeam('right')}>{RIGHT_TEAM_LABEL}</button>
  </div>
);

export default ChooseTeam;
