import React from 'react';

interface GameDialogProps {
  message: string;
  onClose: () => void;
}

/**
 * Simple modal dialog for win/lose messages.
 */
const GameDialog: React.FC<GameDialogProps> = ({ message, onClose }) => (
  <div className="game-dialog">
    <div className="dialog-content">
      <p>{message}</p>
      <button onClick={onClose}>OK</button>
    </div>
  </div>
);

export default GameDialog;