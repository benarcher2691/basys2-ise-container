----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:53:05 03/14/2013 
-- Design Name: 
-- Module Name:    b_register - Behavioral 
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

entity b_register is
    Port ( d    : in  STD_LOGIC_VECTOR (15 downto 0);
           load : in  STD_LOGIC;
           clk  : in  STD_LOGIC;
           o    : out  STD_LOGIC_VECTOR (15 downto 0) := x"0000");
end b_register;


architecture behavioural of b_register is 

begin

process (clk) begin
	if (clk'event and clk = '1' and load = '1') then
		o <= d;
	end if;	
end process;

end architecture;

