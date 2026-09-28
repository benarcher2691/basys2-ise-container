----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:05:04 03/13/2013 
-- Design Name: 
-- Module Name:    b_alu - Structural 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity b_alu is
    Port ( x  : in   std_logic_vector (15 downto 0);
           y  : in   std_logic_vector (15 downto 0);
           zx : in   STD_LOGIC;
           nx : in   STD_LOGIC;
           zy : in   STD_LOGIC;
           ny : in   STD_LOGIC;
           f  : in   STD_LOGIC;
           no : in   STD_LOGIC;
           o  : out  std_logic_vector (15 downto 0);
           zr : out  STD_LOGIC;
           ng : out  STD_LOGIC);
end b_alu;

architecture behavioural of b_alu is

signal code : std_logic_vector(5 downto 0);
signal r : signed (15 downto 0);

begin
	code <= zx & nx & zy & ny & f & no;

	r <= 	x"0000"							when code = "101010" else
			x"0001" 							when code = "111111" else
			x"FFFF" 							when code = "111010" else
			signed(x) 						when code = "001100" else
			signed(y) 						when code = "110000" else
			not signed(x) 					when code = "001101" else
			not signed(y) 					when code = "110001" else
			-signed(x) 						when code = "001111" else
			-signed(y) 						when code = "110011" else
			(signed(x) + 1)				when code = "011111" else
			(signed(y) + 1)				when code = "110111" else
			(signed(x) - 1)				when code = "001110" else
			(signed(y) - 1)				when code = "110010" else
			(signed(x) + signed(y))		when code = "000010" else
			(signed(x) - signed(y))		when code = "010011" else
			(signed(y) - signed(x))		when code = "000111" else
			(signed(x) and signed(y))	when code = "000000" else
			(signed(x) or signed(y));
				
	zr <= '1' when r = x"0000" else '0';
	ng <= '1' when signed(r) < 0 else '0';
		
	o <= std_logic_vector(r);	
		
end architecture behavioural;