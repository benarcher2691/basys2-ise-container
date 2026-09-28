----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:51:24 04/05/2013 
-- Design Name: 
-- Module Name:    anodeCtrl - Behavioral 
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

entity anodeCtrl is
    Port ( clk : in  STD_LOGIC;
           f : out  STD_LOGIC_VECTOR (3 downto 0));
end anodeCtrl;

architecture Behavioral of anodeCtrl is
signal i : std_logic_vector(19 downto 0);
signal j : std_logic_vector(1 downto 0);

begin
process (clk)

begin
	if (clk'event and clk = '1') then
		if (i > x"186A0")then
			i <= x"00000";
			if (j = "00") then
				j <= "01";
				f <= "1110";
			elsif (j = "01") then
				j <= "10";
				f <= "1101";
			elsif (j = "10") then
				j <= "11";
				f <= "1011";
			elsif (j = "11") then			
				j <= "00";
				f <= "0111";
			else
				j <= "00";
				f <= "1111";
			end if;		
		else
			i <= i + 1;
		end if;
	end if;		
end process;

end Behavioral;

