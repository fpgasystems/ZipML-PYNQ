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

entity fp_subtract_mult is
port (
	clk : in std_logic;

	trigger : in std_logic;
	dot_product : in std_logic_vector(31 downto 0);
	b_to_subtract : in std_logic_vector(31 downto 0);
	stepsize : in std_logic_vector(31 downto 0);
	stepsize_times_cost_positive : in std_logic_vector(31 downto 0);
	stepsize_times_cost_negative : in std_logic_vector(31 downto 0);

	result_valid : out std_logic;
	result : out std_logic_vector(31 downto 0));
end fp_subtract_mult;

architecture behavioral of fp_subtract_mult is

constant FP_SUB_LATENCY : integer := 7;
constant FP_COMPARE_LATENCY : integer := 2;

constant one : std_logic_vector(31 downto 0) := X"3f800000";

signal dot_product_minus_b_valid : std_logic;
signal dot_product_minus_b : std_logic_vector(31 downto 0);

signal a_less_than_b_valid : std_logic;
signal a_less_than_b : std_logic_vector(7 downto 0);

signal determiner : std_logic_vector(31 downto 0);
signal apply_gradient : std_logic_vector(FP_SUB_LATENCY-FP_COMPARE_LATENCY-1 downto 0);

signal b_to_subtract_sign : std_logic_vector(FP_SUB_LATENCY-1 downto 0);
signal selected_multiplier : std_logic_vector(31 downto 0);

signal do_linreg_or_l2svm : std_logic;

component xlnx_fp_sub
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

component xlnx_fp_lessthan
port (
	aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_result_tvalid : OUT STD_LOGIC;
    m_axis_result_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0));
END component;

begin

subtract: xlnx_fp_sub
port map (
	aclk => clk,
	s_axis_a_tvalid => trigger,
	s_axis_a_tdata => dot_product,
	s_axis_a_tlast => '0',
	s_axis_b_tvalid => trigger,
	s_axis_b_tdata => b_to_subtract,
	m_axis_result_tvalid => dot_product_minus_b_valid,
	m_axis_result_tdata => dot_product_minus_b);

determiner <= (dot_product(31) XOR b_to_subtract(31)) & dot_product(30 downto 0);
lessthan: xlnx_fp_lessthan
port map (
	aclk => clk,
	s_axis_a_tvalid => trigger,
	s_axis_a_tdata => determiner,
	s_axis_b_tvalid => trigger,
	s_axis_b_tdata => one,
	m_axis_result_tvalid => a_less_than_b_valid,
	m_axis_result_tdata => a_less_than_b);

selected_multiplier <= 	stepsize when do_linreg_or_l2svm = '1' else
						(others => '0') when apply_gradient(FP_SUB_LATENCY-FP_COMPARE_LATENCY-1) = '0' else
						stepsize_times_cost_positive when b_to_subtract_sign(FP_SUB_LATENCY-1) = '0' else 
						stepsize_times_cost_negative;

selected_multiplier_mult: xlnx_fp_mult
port map (
	aclk => clk,
	s_axis_a_tvalid => dot_product_minus_b_valid,
	s_axis_a_tdata => selected_multiplier,
	s_axis_a_tlast => '0',
	s_axis_b_tvalid => dot_product_minus_b_valid,
	s_axis_b_tdata => dot_product_minus_b,
	m_axis_result_tvalid => result_valid,
	m_axis_result_tdata => result);

process(clk)
begin
if clk'event and clk = '1' then
	if stepsize_times_cost_positive = X"bf800000" and stepsize_times_cost_negative = X"bf800000" then
		do_linreg_or_l2svm <= '1'; -- linreg
	else
		do_linreg_or_l2svm <= '0'; -- l2svm
	end if;

	b_to_subtract_sign(0) <= b_to_subtract(31);
	for k in 1 to FP_SUB_LATENCY-1 loop
		b_to_subtract_sign(k) <= b_to_subtract_sign(k-1);
	end loop;

	apply_gradient(0) <= a_less_than_b(0);
	for k in 1 to FP_SUB_LATENCY-FP_COMPARE_LATENCY-1 loop
		apply_gradient(k) <= apply_gradient(k-1);
	end loop;
end if;
end process;

end architecture;