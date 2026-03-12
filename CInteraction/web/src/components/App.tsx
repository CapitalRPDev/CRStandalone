import React, { useState } from "react";
import "./App.css";
import { useNuiEvent } from "../hooks/useNuiEvent";
import Interaction3D from "./Interaction3D";

import { debugData } from "../utils/debugData";

debugData<any>([
  {
    action: "show3DInteraction",
    data: {
      options: [
        { label: "Rob ATM", sublabel: "Steal the cash", icon: "fa-solid fa-money-bill" },
        { label: "Check Balance", sublabel: "View your funds", icon: "fa-solid fa-eye" },
      ],
      selectedIndex: 1,
    }
  }
]);


const App: React.FC = () => {
  const [interaction, setInteraction] = useState<{
    options: { label: string; sublabel?: string; icon: string }[];
    selectedIndex: number;
    visible: boolean;
  }>({
    options: [],
    selectedIndex: 1,
    visible: false,
  });

  useNuiEvent<any>("show3DInteraction", (data) => {
    setInteraction({
      options: data.options,
      selectedIndex: data.selectedIndex,
      visible: true,
    });
  });

  useNuiEvent<any>("update3DInteraction", (data) => {
    setInteraction((prev) => ({
      ...prev,
      options: data.options,
      selectedIndex: data.selectedIndex,
    }));
  });

  useNuiEvent<any>("hide3DInteraction", () => {
    setInteraction({ options: [], selectedIndex: 1, visible: false });
  });

  return (
    <div className="nui-wrapper">
      <Interaction3D
        options={interaction.options}
        selectedIndex={interaction.selectedIndex}
        visible={interaction.visible}
      />
    </div>
  );
};

export default App;