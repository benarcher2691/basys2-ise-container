----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:08:12 03/18/2013 
-- Design Name: 
-- Module Name:    b_cpu - Behavioral 
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

entity b_cpu is
    Port ( inM 			: in  STD_LOGIC_VECTOR (15 downto 0);
           clk 			: in  STD_LOGIC;
           instruction 	: in  STD_LOGIC_VECTOR (15 downto 0);
           reset 			: in  STD_LOGIC;
           outM 			: out  STD_LOGIC_VECTOR (15 downto 0);
           writeM 		: out  STD_LOGIC;
           addressM 		: out  STD_LOGIC_VECTOR (10 downto 0);
           pc 				: out  STD_LOGIC_VECTOR (9 downto 0));
end b_cpu;

architecture Structural of b_cpu is
	
component b_decode
	port(
		instruction 	: in std_logic_vector(15 downto 0);          
		zr 				: in std_logic;
		ng 				: in std_logic;
		ctrlmux0 		: out std_logic;
		ctrlrega 		: out std_logic;
		ctrlmux1 		: out std_logic;
		ctrlregd 		: out std_logic;
		ctrlalu 			: out std_logic_vector(5 downto 0);
		ctrlpc 			: out std_logic;
		ctrlwritem 		: out std_logic;
		instructionOut	: out std_logic_vector(15 downto 0)    
		);
	end component;
	
component b_register
	port(
		d 		: in std_logic_vector(15 downto 0);
		load 	: in std_logic;
		clk 	: in std_logic;          
		o 		: out std_logic_vector(15 downto 0)
		);
	end component;	
	
component b_mux16
	port(
		a 		: in std_logic_vector(15 downto 0);
		b 		: in std_logic_vector(15 downto 0);
		sel 	: in std_logic;          
		f 		: out std_logic_vector(15 downto 0)
		);
	end component;	
	
component b_pc
	port(
		data 		: in std_logic_vector(9 downto 0);
		load 		: in std_logic;
		reset 	: in std_logic;
		clk	 	: in std_logic;          
		o 			: out std_logic_vector(9 downto 0)
		);
	end component;	
	
component b_alu
	port(
		x 	: in std_logic_vector (15 downto 0);
		y 	: in std_logic_vector (15 downto 0);
		zx : in std_logic;
		nx : in std_logic;
		zy : in std_logic;
		ny : in std_logic;
		f 	: in std_logic;
		no : in std_logic;          
		o 	: out std_logic_vector (15 downto 0);
		zr : out std_logic;
		ng : out std_logic
		);
	end component;	

signal s_ALUout 				: std_logic_vector(15 downto 0);
signal s_MUX0_out				: std_logic_vector(15 downto 0);
signal s_loadA 				: std_logic;
signal s_regA 					: std_logic_vector(15 downto 0);
signal s_ALUx 					: std_logic_vector (15 downto 0);	
signal s_ALUy 					: std_logic_vector (15 downto 0);	
signal s_selMUX0 				: std_logic;
signal s_selMUX1 				: std_logic; 
signal s_loadD 				: std_logic;
signal s_ALUzero				: std_logic;
signal s_ALUneg				: std_logic;
signal s_ALUctrl 				: std_logic_vector(5 downto 0);
signal s_loadPC				: std_logic;
signal s_instructionToMUX0	: std_logic_vector (15 downto 0);
begin

b_decode_0: b_decode port map(
		instruction => instruction,
		zr => s_ALUzero,
		ng => s_ALUneg,
		ctrlmux0 => s_selMUX0,
		ctrlrega => s_loadA,
		ctrlmux1 => s_selMUX1,
		ctrlregd => s_loadD,
		ctrlalu => s_ALUctrl,
		ctrlpc => s_loadPC,
		ctrlwritem => writeM,
		instructionOut => s_instructionToMUX0	
	);
	
b_register_A: b_register port map(
		d => s_MUX0_out,
		load => s_loadA,
		clk => clk,
		o => s_regA 
	);

b_register_D: b_register port map(
		d => s_ALUout,
		load => s_loadD,
		clk => clk,
		o => s_ALUx 
	);	
	
b_mux16_0: b_mux16 port map(
		a => s_ALUout,
		b => s_instructionToMUX0,
		sel => s_selMUX0,
		f => s_MUX0_out
	);

b_mux16_1: b_mux16 port map(
		a => s_regA,
		b => inM,
		sel => s_selMUX1,
		f => s_ALUy
	);

b_pc_0: b_pc port map(
		data => s_regA (9 downto 0),
		load => s_loadPC,
		reset => reset,
		clk => clk,
		o => pc
	);	
	
b_alu_0: b_alu port map(
		x => s_ALUx,
		y => s_ALUy,
		zx => s_ALUctrl(5),
		nx => s_ALUctrl(4),
		zy => s_ALUctrl(3),
		ny => s_ALUctrl(2),
		f => s_ALUctrl(1),
		no => s_ALUctrl(0),
		o => s_ALUout,
		zr => s_ALUzero,
		ng => s_ALUneg
	);	

outM <= s_ALUout;	

addressM <= s_regA(10 downto 0);
	
end Structural;

