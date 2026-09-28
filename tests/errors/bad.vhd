-- Deliberate syntax error: tests/regress.sh checks XST's error path.
library ieee;
use ieee.std_logic_1164.all;
entity bad is port (a : in std_logic; y : out std_logic); end bad;
architecture rtl of bad is begin
    y <= a
end rtl;
