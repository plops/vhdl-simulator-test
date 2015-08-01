library ieee;
use ieee.std_logic_1164.all;

-- https://ashwith.wordpress.com/2011/02/07/vhdl-in-alliance-behavioral-simulations/

entity jk_ff is
port
(
 clk  : in  std_logic;
 J    : in  std_logic;
 K    : in  std_logic;
 Q    : out std_logic;
 Qbar : out std_logic
);
end jk_ff;

architecture jk_ff_behavioral of jk_ff is
begin
 process(clk)
 variable Q_temp, Qbar_temp : std_logic;
 variable JK_temp : std_logic_vector (1 downto 0) := "00";
 begin

 if rising_edge(clk) then
  JK_temp := (J & K);
  case JK_temp is
   when "00"   => Q_temp := Q_temp;
   when "01"   => Q_temp := '0';
   when "10"   => Q_temp := '1';
   when "11"   => Q_temp := not Q_temp;
   when others => Q_temp := Q_temp;
  end case;
  Q         <= Q_temp;
  Qbar_temp := not Q_temp;
  Qbar      <= Qbar_temp;
  end if;

 end process;

end jk_ff_behavioral;
