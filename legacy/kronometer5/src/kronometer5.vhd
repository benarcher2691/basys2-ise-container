----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:29:06 04/06/2013 
-- Design Name: 
-- Module Name:    kronometer5 - Behavioral 
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
library UNISIM;
use UNISIM.VComponents.all;

entity kronometer5 is
    Port ( mclk : in  STD_LOGIC;
			  rst	: in std_logic;
			  start : in std_logic;
			  stop : in std_logic;
           seg : out  STD_LOGIC_VECTOR (7 downto 0);
           an : out  STD_LOGIC_VECTOR (3 downto 0));
end kronometer5;

architecture Behavioral of kronometer5 is

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

component timeClock
	port(
		clkIn : in std_logic;      
		rst	: in std_logic;	
		e : in std_logic;
		clkOut : out std_logic
		);
	end component;	
	
component timectrl
	port(
		clk : in std_logic;  
		rst : in std_logic;  	
		start : in std_logic;
		stop : in std_logic;
		e : out std_logic;
		M : out std_logic_vector(3 downto 0);
		C : out std_logic_vector(3 downto 0);
		X : out std_logic_vector(3 downto 0);
		I : out std_logic_vector(3 downto 0)
		);
	end component;	

signal s0 : std_logic_vector(3 downto 0);
signal s1, s2 : std_logic;
signal sM, sC, sX, sI : std_logic_vector(7 downto 0);
signal sM_2, sC_2, sX_2, sI_2 : std_logic_vector(3 downto 0);
signal e0 : std_logic;

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

begin

timeClock_0: timeClock port map(
		clkIn => mclk,
		rst => rst,
		e => e0,
		clkOut => s1
	);
	
Inst_timeCtrl: timeCtrl port map(
		clk => s2,
		rst => rst,
		start => start,
		stop => stop,
		e => e0,
		M => sM_2,
		C => sC_2,
		X => sX_2,
		I => sI_2
	);	

decoder_M: decoder port map(
		a => sM_2,
		f => sM
	);
	
decoder_C: decoder port map(
		a => sC_2,
		f => sC
	);
	
decoder_X: decoder port map(
		a => sX_2,
		f => sX
	);
	
decoder_I: decoder port map(
		a => sI_2,
		f => sI
	);

anodeCtrl_0: anodeCtrl port map(
		clk => mclk,
		f => s0
	);

segmentCtrl_0: segmentCtrl port map(
		M => sM,
		C => sC,
		X => sX,
		I => sI,
		sel => s0,
		f => seg,
		g => an
	);
	
 BUFG_inst : BUFG
   port map (
      O => s2,     -- Clock buffer output
      I => s1      -- Clock buffer input
   );

end Behavioral;