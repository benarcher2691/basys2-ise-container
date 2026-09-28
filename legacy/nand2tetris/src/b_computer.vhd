----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:18:21 03/19/2013 
-- Design Name: 
-- Module Name:    b_computer - Behavioral 
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

entity b_computer is
    Port ( reset    : in  STD_LOGIC;
           mclk     : in  STD_LOGIC;
			  sw       : in std_logic_vector(3 downto 0);
			  an       : out std_logic_vector(3 downto 0);
			  seg      : out std_logic_vector(7 downto 0);
			  pcOUT    : out std_logic_vector(5 downto 0);
			  clkOUT   : out std_logic;
			  resetOUT : out std_logic
			  );
end b_computer;

architecture Structural of b_computer is
attribute box_type : string;

component f_5mz
	port(
		clkIN : IN std_logic;  
		f     : OUT std_logic
		);
	end component;
	
component b_cpu
	port(
		inM 			: in std_logic_vector(15 downto 0);
		clk 			: in std_logic;
		instruction : in std_logic_vector(15 downto 0);
		reset 		: in std_logic;          
		outM 			: out std_logic_vector(15 downto 0);
		writeM 		: out std_logic;
		addressM 	: out std_logic_vector(10 downto 0);
		pc 			: out std_logic_vector(9 downto 0)
		);
	end component;
	
component b_rom1024
  port (
    clka  : in std_logic;
    addra : in std_logic_vector(9 downto 0);
    douta : out std_logic_vector(15 downto 0)
  );
end component; 
attribute box_type of b_rom1024 : component is "black_box";

component b_ram2048
  port (
    clka  : in std_logic;
    wea   : in std_logic_vector(0 downto 0);
    addra : in std_logic_vector(10 downto 0);
    dina  : in std_logic_vector(15 downto 0);
    douta : out std_logic_vector(15 downto 0);
    clkb  : in std_logic;
    web   : in std_logic_vector(0 downto 0);
    addrb : in std_logic_vector(10 downto 0);
    dinb  : in std_logic_vector(15 downto 0);
    doutb : out std_logic_vector(15 downto 0)
  );
end component;
attribute box_type of b_ram2048 : component is "black_box";

-- 7segments; for debugging purpose
component screen
	port(
		clk     : in std_logic;
		data    : in std_logic_vector(15 downto 0);     
		segment : out std_logic_vector(7 downto 0);
		anodes  : out std_logic_vector(3 downto 0)
		);
end component;

signal addressROM : std_logic_vector(9 downto 0);
signal addressRAM : std_logic_vector(10 downto 0);
signal dataRAM    : std_logic_vector(15 downto 0);
signal dataROM    : std_logic_vector(15 downto 0);
signal s0         : std_logic_vector(15 downto 0);
signal t0         : std_logic_vector(0 downto 0);
signal t1         : std_logic_vector(0 downto 0);
signal dataB_RAM  : std_logic_vector(15 downto 0);
signal addrB_RAM  : std_logic_vector(10 downto 0);
signal clk        : std_logic;

begin

f_5Mz_0: f_5Mz PORT MAP(
		clkIN => mclk,
		f => clk
	);	
	
b_cpu_0: b_cpu port map(
		inM => dataRAM,
		clk => clk,
		instruction => dataROM,
		reset => reset,
		outM => s0,
		writeM => t0(0),
		addressM(10 downto 0) => addressRAM,
		pc => addressROM
	);
	
b_rom1024_0 : b_rom1024
  port map (
    clka =>  not clk, -- clocked on negative flank
    addra => addressROM,
    douta => dataROM
  );	
  
 b_ram2048_0 : b_ram2048
  PORT MAP (
	 clka => not clk, -- clocked on negative flank
    wea => t0,
    addra => addressRAM,
    dina => s0,
    douta => dataRAM,
    clkb => clk,
    web => t1,
    addrb => addrB_RAM,
    dinb => x"ABCD", -- never used
    doutb => dataB_RAM
  ); 	
  
  -- debug purpose
  -- read the first 16 RAM memory addresses based on sw0 - sw3
  -- use the second RAM data channel
  screen_0: screen PORT MAP(
		clk => clk,
		data => dataB_RAM,
		segment => seg,
		anodes => an
	);
  
t1(0) <= '0'; 

addrB_RAM <= "0000000" & sw;

pcOUT <= addressROM(5 downto 0);
clkOUT <= clk;
resetOUT <= reset;

end Structural;

