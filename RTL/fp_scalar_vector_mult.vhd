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

entity fp_scalar_vector_mult is
generic (VECTOR_SIZE : integer := 16);
port (
	clk : in std_logic;

	trigger : in std_logic;
	scalar : in std_logic_vector(31 downto 0);
	vector : in std_logic_vector(32*VECTOR_SIZE-1 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(32*VECTOR_SIZE-1 downto 0));
end fp_scalar_vector_mult;

architecture behavioral of fp_scalar_vector_mult is

type result_type is array (VECTOR_SIZE-1 downto 0) of std_logic_vector(31 downto 0);
signal internal_result : result_type;
signal internal_result_valid : std_logic_vector(VECTOR_SIZE-1 downto 0);

component xlnx_fp_mult
port (
	aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_a_tlast : IN STD_LOGIC;
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_result_tvalid : OUT STD_LOGIC;
    m_axis_result_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_result_tlast : OUT STD_LOGIC);
end component;

begin

result_valid <= internal_result_valid(0);

GenFP_MULT: for k in 0 to VECTOR_SIZE-1 generate
	fp_mult: xlnx_fp_mult 
	port map (
		aclk => clk,
		s_axis_a_tvalid => trigger,
		s_axis_a_tdata => scalar,
		s_axis_a_tlast => '0',
		s_axis_b_tvalid => trigger,
		s_axis_b_tdata => vector(k*32+31 downto k*32),
		m_axis_result_tvalid => internal_result_valid(k),
		m_axis_result_tdata => internal_result(k));

	result(k*32+31 downto k*32) <= internal_result(k);
end generate GenFP_MULT;

end architecture;