----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:22:38 04/06/2013 
-- Design Name: 
-- Module Name:    timeCtrl - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity timeCtrl is
    Port ( clk : in  STD_LOGIC;
			  rst: in std_logic;
			  start : in std_logic;
			  stop : in std_logic;
			  e : out std_logic;
           M : out  STD_LOGIC_VECTOR (3 downto 0);
           C : out  STD_LOGIC_VECTOR (3 downto 0);
           X : out  STD_LOGIC_VECTOR (3 downto 0);
           I : out  STD_LOGIC_VECTOR (3 downto 0));
end timeCtrl;

architecture Behavioral of timeCtrl is
signal sM	: std_logic_vector (3 downto 0) := "0000";
signal sC	: std_logic_vector (3 downto 0) := "0000";
signal sX	: std_logic_vector (3 downto 0) := "0000";
signal sI	: std_logic_vector (3 downto 0) := "0000";

type state is (COUNT, PAUSE, RESET);
signal s : state := RESET;

begin

buttons : process (rst, start, stop)
begin
	if (rst = '1') then
		s <= RESET;
		e <= '0';
	elsif (start = '1') then
		s <= COUNT;
		e <= '1';
	elsif (stop = '1') then
		s <= PAUSE;
		e <= '0';
	end if;	

end process;


counting : process (clk, rst)
begin
	if (rst = '1') then
		sM <= "0000";
		sC <= "0000";
		sX <= "0000";
		sI <= "0000";
	elsif (clk'event and clk = '1') then
		case s is
			when COUNT =>
				if (sI = "1001") then
					sI <= (others => '0');
					sX <= sX + '1';
					if (sX = "1001") then
						sX <= (others => '0');
						sC <= sC + '1';
						if (sC = "0101") then
							sC <= (others => '0');
							sM <= sM + '1';
							if (sM = "1001") then
								sM <= (others => '0');
							end if;
						end if;
					end if;			
				else
					sI <= sI + '1';			
				end if;
			when 	PAUSE =>
				sM <= sM;
				sC <= sC;
				sX <= sX;
				sI <= sI;
			when RESET =>
				sM <= "0000";
				sC <= "0000";
				sX <= "0000";
				sI <= "0000";
		end case;	
	end if;

end process;

M <= sM;
C <= sC;
X <= sX;
I <= sI;


end Behavioral;

