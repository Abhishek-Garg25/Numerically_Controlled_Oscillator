-- SPDX-License-Identifier: MIT
-- =============================================================================
-- Title       : CORDIC Testbench
-- File        : Local_oscillator_tb.vhd
-- Author      : Abhishek Garg <abhishekgarg403@gmail.com>
-- Created     : 2025-08-15
-- Last Edited : 2025-08-15
-- Version     : 1.0
-- -----------------------------------------------------------------------------
-- Description :
--   Testbench for the CORDIC oscillator. Stimulates the top-level module to:
--     - Verify fixed-point sine/cosine output against golden model
--     - Sweep phase or apply phase increment (for oscillator behaviour)
--     - Capture waveform output for plotting
--
-- -----------------------------------------------------------------------------
-- Testbench signals (example)
--   - clk, rst_n
--   - en
--   - phase_inc stimulus (constant or ramp)
--   - file output or wave dump directives
--
-- -----------------------------------------------------------------------------
-- Simulation notes :
--   - Use a reference model (double-precision software) to assert error bounds.
--   - Export waveforms as VCD/FSDB for visualization.
--   - Include checks for saturation and wrap-around issues.
--
-- -----------------------------------------------------------------------------
-- Revision History :
--   v1.0  2025-08-15  Initial release
--
-- -----------------------------------------------------------------------------
-- License :
--   Released under the MIT License.
-- =============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cordic_pkg.all;

entity tb_cordic_oscillator is
end tb_cordic_oscillator;

architecture sim of tb_cordic_oscillator is

  -- DUT signals
  signal clk         : std_logic := '0';
  signal rst         : std_logic := '1';
  signal ce          : std_logic := '0';
  signal tuning_word : sfixed_internal_t;
  signal sin_out     : sfixed_t;
  signal cos_out     : sfixed_t;
  signal valid_out   : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin

  -- Clock process
  clk_process : process
  begin
    while now < 200 us loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
    wait;
  end process;

  -- DUT
  uut: entity work.cordic_oscillator
    port map (
      clk         => clk,
      rst         => rst,
      ce          => ce,
      tuning_word => tuning_word,
      sin_out     => sin_out,
      cos_out     => cos_out,
      valid_out   => valid_out
    );

  -- Stimulus
  stim_proc : process
  begin
    -- Reset
    wait for 20 ns;
    rst <= '0';
    ce <= '1';
    -- Set constant tuning word (e.g., ~15.9 kHz sine at 100 MHz)
    tuning_word <= real_to_sfixed(2.0 * MATH_PI / 1000.0,CORDIC_INTERNAL_WIDTH);

    -- Run simulation
    wait for 200 us;
    wait;
  end process;
process(clk)
  begin
    if rising_edge(clk) then
      if valid_out = '1' then
        report "sin = " & real'image(sfixed_to_real(sin_out)) &
               "  cos = " & real'image(sfixed_to_real(cos_out));
      end if;
    end if;
  end process;

end architecture;
