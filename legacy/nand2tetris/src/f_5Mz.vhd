----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:53:32 04/14/2013 
-- Design Name: 
-- Module Name:    f_5Mz - Behavioral 
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

entity f_5Mz is
    Port ( clkIN 	: in  STD_LOGIC;
           f 		: out  STD_LOGIC);
end f_5Mz;

architecture Behavioral of f_5Mz is

signal i	: std_logic_Vector (4 downto 0) := "00000";
signal j : std_logic := '0';

begin

process (clkIN)
begin
	if (clkIN'event and clkIN = '1') then
		if (i > x"19")then
			i <= (others => '0');
			j <= not j;
		else
			i <= i + 1;
		end if;	
	end if;
end process;

f <= j;

end Behavioral;

