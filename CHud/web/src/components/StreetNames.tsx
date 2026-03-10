import React from "react";

interface StreetNamesProps {
  direction: string;
  locationName: string;
  streetName: string;
}

const StreetNames: React.FC<StreetNamesProps> = ({ direction, locationName, streetName }) => {
  return (
    <div className="streetnames-container">
      <div className="direction-badge">
        {direction}
      </div>
      <div className="location-info">
        <div className="location-name">{locationName}</div>
        <div className="street-name">{streetName}</div>
      </div>
    </div>
  );
};

export default StreetNames;