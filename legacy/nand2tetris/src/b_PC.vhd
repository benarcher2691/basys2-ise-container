----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:48:56 03/16/2013 
-- Design Name: 
-- Module Name:    b_PC - Behavioral 
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

entity b_PC is
    Port ( data  : in  STD_LOGIC_VECTOR (9 downto 0);
           load  : in  STD_LOGIC;
           --inc : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           clk   : in  STD_LOGIC;
           o     : out  STD_LOGIC_VECTOR (9 downto 0));
end b_PC;

architecture behavioural of b_PC is
attribute box_type : string;

COMPONENT b_program_counter
  PORT (
    clk  : IN STD_LOGIC;
    sclr : IN STD_LOGIC;
    load : IN STD_LOGIC;
    l    : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    q    : OUT STD_LOGIC_VECTOR(9 DOWNTO 0)
  );
END COMPONENT;
attribute box_type of b_program_counter : component is "black_box";

begin

b_program_counter_0 : b_program_counter
  PORT MAP (
    clk => clk,
    sclr => reset,
    load => load,
    l => data,
    q => o
  );
  
 -- o(15 downto 10) <= "000000";

end architecture behavioural;