----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:32:11 04/05/2013 
-- Design Name: 
-- Module Name:    decoder - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity decoder is
    Port ( a : in  STD_LOGIC_VECTOR (3 downto 0);
           f : out  STD_LOGIC_VECTOR (7 downto 0)); -- f(7) = dp
end decoder;

architecture Behavioral of decoder is

begin
	with a select
		f <= 	"11000000" when "0000",
				"11111001" when "0001",
				"10100100" when "0010",
				"10110000" when "0011",
				"10011001" when "0100",
				"10010010" when "0101",
				"10000010" when "0110",
				"11111000" when "0111",
				"10000000" when "1000",
				"10010000" when "1001",
				"10001000" when "1010",
				"00000011" when "1011",
				"11000110" when "1100",
				"10100001" when "1101",
				"10000110" when "1110",
				"10001110" when "1111",
				"11111111" when others;
				
end Behavioral;

