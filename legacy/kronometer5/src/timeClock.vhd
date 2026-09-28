----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:13:22 04/06/2013 
-- Design Name: 
-- Module Name:    timeClock - Behavioral 
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

entity timeClock is
    Port ( 	clkIn : in  STD_LOGIC;
				rst	: in std_logic;	
				e		: in std_logic;
				clkOut : out  STD_LOGIC);
end timeClock;

architecture Behavioral of timeClock is

signal i	: std_logic_Vector (25 downto 0);
signal j : std_logic := '0';

begin

process (clkIn, rst)
begin
	if (rst = '1') then 
		i <= "00000000000000000000000000";	
	elsif (clkIn'event and clkIn = '1' and e = '1') then
		--if (i > x"17D7840")then 
		if (i > x"2625A0")then
			i <= (others => '0');
			j <= not j;
		else
			i <= i + 1;
		end if;	
	end if;
end process;

clkOut <= j;

end Behavioral;

