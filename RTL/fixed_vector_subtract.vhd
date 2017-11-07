----------------------------------------------------------------------------
--  Copyright (C) 2017 Kaan Kara - Systems Group, ETH Zurich

--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU Affero General Public License as published
--  by the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.

--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU Affero General Public License for more details.

--  You should have received a copy of the GNU Affero General Public License
--  along with this program. If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fixed_vector_subtract is
generic (VECTOR_SIZE : integer := 16);
port (
	clk : in std_logic;

	trigger : in std_logic;
	vector1 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);
	vector2 : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);
	lambda_in_bitshift : std_logic_vector(31 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(32*VECTOR_SIZE-1 downto 0));
end fixed_vector_subtract;

architecture behavioral of fixed_vector_subtract is

begin

GenFP_MULT: for k in 0 to VECTOR_SIZE-1 generate
	--result(k*32+31 downto k*32) <= 	std_logic_vector( signed(vector1(k*32+31 downto k*32)) - signed(vector2(k*32+31 downto k*32)) ) when unsigned(lambda_in_bitshift) = 0 else
	--								std_logic_vector( signed(vector1(k*32+31 downto k*32)) - signed(vector2(k*32+31 downto k*32)) - shift_right(signed(vector1(k*32+31 downto k*32)), to_integer(unsigned(lambda_in_bitshift)) ) );
	result(k*32+31 downto k*32) <= 	std_logic_vector( signed(vector1(k*32+31 downto k*32)) - signed(vector2(k*32+31 downto k*32)) );
end generate GenFP_MULT;

result_valid <= trigger;

end architecture;