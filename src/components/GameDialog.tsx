import React from 'react';

interface GameDialogProps {
  message: string;
  onClose: () => void;
}

const GameDialog: React.FC<GameDialogProps> = ({ message, onClose }) => (
  <div className="game-dialog">
    <div className="dialog-content">
      <p>{message}</p>
      <button onClick={onClose}>OK</button>
    </div>
  </div>
);

export default GameDialog;