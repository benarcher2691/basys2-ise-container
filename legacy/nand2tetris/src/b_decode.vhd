----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:14:29 03/18/2013 
-- Design Name: 
-- Module Name:    b_decode - Behavioral 
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

entity b_decode is
    Port ( instruction : in  STD_LOGIC_VECTOR (15 downto 0);
			  zr             : in  STD_LOGIC;
			  ng             : in  STD_LOGIC;
           ctrlMux0       : out  STD_LOGIC;
           ctrlRegA       : out  STD_LOGIC;
           ctrlMux1       : out  STD_LOGIC;
           ctrlRegD       : out  STD_LOGIC;
           ctrlALU        : out  STD_LOGIC_VECTOR (5 downto 0);
           ctrlPC         : out  STD_LOGIC; -- ctrlPC=load
           ctrlWriteM     : out  STD_LOGIC;
			  instructionOut : out STD_LOGIC_VECTOR (15 downto 0));
end b_decode;

architecture behavioural of b_decode is

begin
ctrlMux0   <= not instruction(15);
ctrlRegA   <= instruction(5) or (not instruction(15));
ctrlMux1   <= instruction(12) or (not instruction(15));
ctrlRegD   <= instruction(15) and instruction(4);
ctrlALU    <= instruction(11 downto 6);
ctrlWriteM <= instruction(15) and instruction(3);
ctrlPC     <= 	instruction(15) and (
				   (instruction(0) and (not zr) and (not ng)) or 
				   (instruction(2) and (not zr) and ng) or 
				   (instruction(2) and instruction(1) and zr) or 
				   (instruction(1) and zr and (not ng)) );
				
instructionOut <= instruction;				

end behavioural;