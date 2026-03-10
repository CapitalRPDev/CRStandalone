import React from "react";
import { Notification } from "./types";

interface NotifyProps {
  notifications: Notification[];
}

const Notify: React.FC<NotifyProps> = ({ notifications }) => {
  if (notifications.length === 0) return null;

  return (
    <div className="notify-wrapper">
      {notifications.map((n) => (
        <div className="notify-container" key={n.id}>
          <div
            className="notify-icon"
            style={{ background: n.iconColor, boxShadow: `0 0 8px ${n.iconColor}80` }}
          >
            <i className={`fas ${n.icon}`} />
          </div>
          <span className="notify-text">{n.text}</span>
        </div>
      ))}
    </div>
  );
};

export default Notify;