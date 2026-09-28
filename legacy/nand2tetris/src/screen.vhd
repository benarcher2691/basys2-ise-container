----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    06:59:18 04/12/2013 
-- Design Name: 
-- Module Name:    screen - Behavioral 
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

entity screen is
    Port ( clk 		: in  STD_LOGIC;
           data 		: in  STD_LOGIC_VECTOR (15 downto 0);
           segment 	: out  STD_LOGIC_VECTOR (7 downto 0);
           anodes 	: out  STD_LOGIC_VECTOR (3 downto 0));
end screen;

architecture Behavioral of screen is

	component anodectrl
	port(
		clk : in std_logic;          
		f : out std_logic_vector(3 downto 0)
		);
	end component;
	
	component decoder
	port(
		a : in std_logic_vector(3 downto 0);          
		f : out std_logic_vector(7 downto 0)
		);
	end component;	

component segmentctrl
	port(
		M : in std_logic_vector(7 downto 0);
		C : in std_logic_vector(7 downto 0);
		X : in std_logic_vector(7 downto 0);
		I : in std_logic_vector(7 downto 0);
		sel : in std_logic_vector(3 downto 0);          
		f : out std_logic_vector(7 downto 0);
		g : out std_logic_vector(3 downto 0)
		);
	end component;

signal s0 : std_logic_vector(3 downto 0);
signal s1, s2, s3, s4 : std_logic_vector(7 downto 0);

begin

anodeCtrl_0: anodeCtrl PORT MAP(
		clk => clk,
		f => s0
	);
	
decoder_3: decoder PORT MAP(
		a => data(15 downto 12),
		f => s1
	);

decoder_2: decoder PORT MAP(
		a => data(11 downto 8),
		f => s2
	);

decoder_1: decoder PORT MAP(
		a => data(7 downto 4),
		f => s3
	);

decoder_0: decoder PORT MAP(
		a => data(3 downto 0),
		f => s4
	);	

segmentCtrl_0: segmentCtrl port map(
		M => s1,
		C => s2,
		X => s3,
		I => s4,
		sel => s0,
		f => segment,
		g => anodes
	);

end Behavioral;

